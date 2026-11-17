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

Usage:
  class-specific-fdr.py --results_dir DIR --class_prefix tr|TEJ
                        [--fdr 0.01] [--out_basename NAME]
"""
import argparse
import csv
import glob
import os
import sys


def read_psms(path, is_decoy):
    """Percolator PSM table: PSMId, score, q-value, posterior_error_prob,
    peptide, proteinIds."""
    out = []
    with open(path) as fh:
        r = csv.DictReader(fh, delimiter="\t")
        for row in r:
            try:
                score = float(row["score"])
            except (KeyError, ValueError):
                continue
            out.append({
                "PSMId": row.get("PSMId", ""),
                "score": score,
                "peptide": row.get("peptide", ""),
                "proteinIds": row.get("proteinIds", ""),
                "pep": row.get("posterior_error_prob", ""),
                "decoy": is_decoy,
            })
    return out


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
    ap.add_argument("--class_prefix", required=True,
                    help="accession prefix identifying the custom class, e.g. 'tr|TEJ'")
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

    # A decoy of a custom entry carries the decoy prefix in front of the class
    # prefix (rev_tr|TEJ...), so test for the class anywhere in proteinIds.
    custom = [p for p in psms if a.class_prefix in p["proteinIds"]]
    canon = [p for p in psms if a.class_prefix not in p["proteinIds"]]
    print("  custom class : %d PSMs (%d decoy)"
          % (len(custom), sum(p["decoy"] for p in custom)))
    print("  canonical    : %d PSMs (%d decoy)"
          % (len(canon), sum(p["decoy"] for p in canon)))
    if not custom:
        print("\nWARNING: no PSMs matched '%s'. Either the search database carried no "
              "entries of this class, or the prefix is wrong." % a.class_prefix)

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
