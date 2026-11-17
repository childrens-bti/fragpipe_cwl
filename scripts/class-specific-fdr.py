#!/usr/bin/env python3
"""Class-specific FDR for custom (non-canonical) entries in a FragPipe search.

A custom entry -- a translated splice junction, variant or novel ORF -- is
typically supported by exactly ONE peptide. That is the expected case, not a
red flag: the entry only exists to carry a few residues of novel sequence. But
a global protein-level FDR treats it as a single-hit protein and discards it,
so the search can run to completion and report nothing from the very class it
was built to find.

Scoring the class separately fixes that. A custom peptide competes against the
decoys of its OWN class -- tens of thousands of sequences -- rather than against
a 23-million-residue proteome, so the score threshold is set by the size of the
question being asked.

This reads PERCOLATOR output, not psm.tsv. Philosopher has already applied a
global FDR and dropped decoys by the time psm.tsv is written, so the class
calculation has to happen upstream of it. It needs percolator.keep-tsv-files=true
in the workflow.

The custom class is defined in one of two ways:
  --class_fasta FASTA   every entry of the custom FASTA (the search's query_fasta)
                        is in the class, whatever its header looks like. Use this
                        when custom headers share no common label, e.g. a mix of
                        variant, splice-junction and fusion entries.
  --class_prefix STR    every protein whose accession contains STR.

A PSM is assigned to the custom class only if EVERY protein it maps to is a
custom entry. A peptide that also maps to a canonical protein is explained by
the reference proteome, so it is not evidence for the custom entry and is
scored with the canonical class. Decoys are classified the same way, after
removing the decoy prefix.

Usage:
  class-specific-fdr.py --results_dir DIR (--class_fasta FASTA | --class_prefix STR)
                        [--decoy_prefix rev_] [--fdr 0.01] [--out_basename NAME]
"""
import argparse
import csv
import glob
import os
import sys


def read_psms(path, is_decoy):
    """Percolator PSM table: PSMId, score, q-value, posterior_error_prob,
    peptide, proteinIds. proteinIds is one column holding every protein the
    peptide maps to, joined by ';' (with a trailing ';')."""
    out = []
    with open(path) as fh:
        r = csv.DictReader(fh, delimiter="\t")
        for row in r:
            try:
                score = float(row["score"])
            except (KeyError, ValueError):
                continue
            proteins = [p for p in (row.get("proteinIds") or "").split(";") if p]
            out.append({
                "PSMId": row.get("PSMId", ""),
                "score": score,
                "peptide": row.get("peptide", ""),
                "proteins": proteins,
                "proteinIds": ";".join(proteins),
                "pep": row.get("posterior_error_prob", ""),
                "decoy": is_decoy,
            })
    return out


def fasta_ids(path):
    """Protein IDs as FragPipe reports them: the header up to the first space."""
    ids = set()
    with open(path) as fh:
        for line in fh:
            if line.startswith(">"):
                tok = line[1:].split(None, 1)
                if tok:
                    ids.add(tok[0])
    return ids


def qvalues(psms):
    """Target-decoy competition within one class.

    Sorted by score descending, q at each rank is (decoys+1)/targets, then made
    monotonic from the bottom so q never decreases as the threshold loosens.
    The +1 is the standard conservative correction for small classes -- which is
    exactly the regime a custom class is in.
    """
    psms.sort(key=lambda p: p["score"], reverse=True)
    d = t = 0
    for p in psms:
        if p["decoy"]:
            d += 1
        else:
            t += 1
        p["q"] = (d + 1) / t if t else 1.0
    best = 1.0
    for p in reversed(psms):
        best = min(best, p["q"])
        p["q"] = best
    return psms


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--results_dir", required=True)
    cls = ap.add_mutually_exclusive_group(required=True)
    cls.add_argument("--class_fasta",
                     help="custom FASTA; every entry in it is in the custom class")
    cls.add_argument("--class_prefix",
                     help="substring identifying custom accessions, e.g. 'tr|TEJ'")
    ap.add_argument("--decoy_prefix", default="rev_",
                    help="decoy tag (database.decoy-tag in the workflow)")
    ap.add_argument("--fdr", type=float, default=0.01)
    ap.add_argument("--out_basename", default="class_fdr")
    a = ap.parse_args()

    tgt = sorted(glob.glob(os.path.join(a.results_dir, "**", "*_percolator_target_psms.tsv"),
                           recursive=True))
    dec = sorted(glob.glob(os.path.join(a.results_dir, "**", "*_percolator_decoy_psms.tsv"),
                           recursive=True))
    if not tgt:
        sys.exit("ERROR: no *_percolator_target_psms.tsv under %s\n"
                 "Percolator TSVs are required; set percolator.keep-tsv-files=true "
                 "in the workflow and re-run." % a.results_dir)
    print("percolator tables: %d target, %d decoy" % (len(tgt), len(dec)))

    psms = []
    for f in tgt:
        psms += read_psms(f, False)
    for f in dec:
        psms += read_psms(f, True)
    print("PSMs read: %d (%d decoy)" % (len(psms), sum(p["decoy"] for p in psms)))

    def strip_decoy(pid):
        return pid[len(a.decoy_prefix):] if pid.startswith(a.decoy_prefix) else pid

    if a.class_fasta:
        ids = fasta_ids(a.class_fasta)
        print("custom class: %d entries in %s" % (len(ids), a.class_fasta))
        if not ids:
            sys.exit("ERROR: no FASTA headers found in %s" % a.class_fasta)
        is_custom = lambda pid: strip_decoy(pid) in ids
        label = a.class_fasta
    else:
        is_custom = lambda pid: a.class_prefix in strip_decoy(pid)
        label = a.class_prefix

    custom, canon = [], []
    seen = set()
    for p in psms:
        flags = [is_custom(pid) for pid in p["proteins"]]
        if flags and all(flags):
            custom.append(p)
        else:
            canon.append(p)
        if any(flags) and not p["decoy"]:
            seen.update(strip_decoy(pid) for pid, f in zip(p["proteins"], flags) if f)
    shared = sum(1 for p in canon
                 if not p["decoy"] and any(is_custom(pid) for pid in p["proteins"]))
    print("  custom class : %d PSMs (%d decoy)"
          % (len(custom), sum(p["decoy"] for p in custom)))
    print("  canonical    : %d PSMs (%d decoy)"
          % (len(canon), sum(p["decoy"] for p in canon)))
    print("  %d target PSMs map to a custom entry AND a canonical protein; "
          "scored as canonical" % shared)
    print("  %d distinct custom entries have at least one target PSM" % len(seen))
    if not custom:
        print("\nWARNING: no PSMs matched the custom class (%s). Either the search "
              "database carried no such entries, or the class definition does not "
              "match the protein IDs in the Percolator tables." % label)

    rows = []
    for name, group in (("custom", custom), ("canonical", canon)):
        if not group:
            continue
        qvalues(group)
        n_t = sum(1 for p in group if not p["decoy"])
        passed = [p for p in group if not p["decoy"] and p["q"] <= a.fdr]
        print("\n%s class at %.1f%% FDR: %d of %d target PSMs pass"
              % (name, 100 * a.fdr, len(passed), n_t))
        # The +1 correction puts a floor on what any class can achieve: with n
        # targets the best possible q is 1/n, so a small class cannot be
        # certified at a tight FDR no matter how good its scores are. Say so,
        # rather than returning an empty result that looks like "nothing found".
        if n_t and 1.0 / n_t > a.fdr:
            print("  NOTE: this class has only %d target PSMs, so the lowest "
                  "achievable q-value is %.3f." % (n_t, 1.0 / n_t))
            print("        Nothing can pass at %.3f regardless of score. Report "
                  "these PSMs with their q-values" % a.fdr)
            print("        rather than as a pass/fail list, or pool the class "
                  "across plexes before scoring.")
        for p in passed:
            rows.append({"class": name, "PSMId": p["PSMId"], "peptide": p["peptide"],
                         "proteinIds": p["proteinIds"], "score": p["score"],
                         "class_qvalue": p["q"], "posterior_error_prob": p["pep"]})

    out = "%s_class_fdr_psms.tsv" % a.out_basename
    with open(out, "w", newline="") as fh:
        w = csv.DictWriter(fh, delimiter="\t", fieldnames=[
            "class", "PSMId", "peptide", "proteinIds", "score",
            "class_qvalue", "posterior_error_prob"])
        w.writeheader()
        w.writerows(rows)
    print("\nwrote %s (%d PSMs)" % (out, len(rows)))


if __name__ == "__main__":
    main()
