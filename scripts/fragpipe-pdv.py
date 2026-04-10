#!/usr/bin/env python3
import argparse
import csv
import re
import subprocess
from collections import defaultdict
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run PDV in batch mode for peptides listed in a combined peptide table, "
            "using FragPipe per-sample psm.tsv files."
        )
    )
    parser.add_argument("results_dir", help="FragPipe results directory (e.g., SAMPLE_results)")
    parser.add_argument("mzml_directory", help="Directory containing mzML inputs")
    parser.add_argument("target_peptide_table", help="*_combined_peptide_control_filtered.tsv file")
    parser.add_argument("output_basename", help="Output basename")
    parser.add_argument(
        "--pdv-jar",
        default="/opt/pdv/PDV.jar",
        help="Path to PDV jar (default: /opt/pdv/PDV.jar)",
    )
    return parser.parse_args()


def read_target_peptides(path: Path) -> set[str]:
    with path.open("r", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        peptide_key = "Peptide Sequence"
        if peptide_key not in (reader.fieldnames or []):
            raise ValueError(
                f"Target peptide table {path} is missing required column '{peptide_key}'"
            )
        peptides = {
            (row.get(peptide_key) or "").strip()
            for row in reader
            if (row.get(peptide_key) or "").strip()
        }
    if not peptides:
        raise ValueError(f"No target peptides found in {path}")
    return peptides


def find_results_samples(results_dir: Path) -> list[Path]:
    candidates = [p for p in results_dir.rglob("psm.tsv") if p.is_file()]
    return sorted(candidates)


def select_pepxml(sample_dir: Path) -> Path | None:
    interact = sorted(sample_dir.glob("interact-*.pep.xml"))
    if interact:
        return interact[0]
    pepxml = sorted(sample_dir.glob("*.pepXML"))
    if pepxml:
        return pepxml[0]
    pepxml_alt = sorted(sample_dir.glob("*.pep.xml"))
    return pepxml_alt[0] if pepxml_alt else None


def index_mzml_files(mzml_directory: Path) -> dict[str, Path]:
    index: dict[str, Path] = {}
    for ext in ("*.mzML", "*.mzml"):
        for path in mzml_directory.rglob(ext):
            index[path.stem] = path
    return index


def extract_scan_number(spectrum_value: str) -> str | None:
    value = (spectrum_value or "").strip()
    match = re.search(r"\.(\d+)\.(\d+)\.[^.\s]+$", value)
    if match:
        return match.group(1)
    match = re.search(r"\.(\d+)\.(\d+)\.", value)
    if match:
        return match.group(1)
    return None


def collect_scan_numbers(psm_file: Path, target_peptides: set[str]) -> list[str]:
    scans: list[str] = []
    with psm_file.open("r", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        fieldnames = reader.fieldnames or []
        peptide_col = "Peptide"
        if peptide_col not in fieldnames:
            peptide_col = "Peptide Sequence" if "Peptide Sequence" in fieldnames else ""
        spectrum_col = "Spectrum"
        if not peptide_col or spectrum_col not in fieldnames:
            raise ValueError(
                f"PSM file {psm_file} must contain '{spectrum_col}' and a peptide column"
            )

        for row in reader:
            peptide = (row.get(peptide_col) or "").strip()
            if peptide not in target_peptides:
                continue
            scan = extract_scan_number(row.get(spectrum_col) or "")
            if scan is not None:
                scans.append(scan)

    # Keep unique scan numbers while preserving first-seen order.
    seen: set[str] = set()
    unique_scans: list[str] = []
    for scan in scans:
        if scan not in seen:
            seen.add(scan)
            unique_scans.append(scan)
    return unique_scans


def run_pdv(
    pdv_jar: Path,
    pepxml_file: Path,
    mzml_file: Path,
    scan_file: Path,
    outdir: Path,
) -> None:
    cmd = [
        "xvfb-run",
        "--auto-servernum",
        "java",
        "-jar",
        str(pdv_jar),
        "-r",
        str(pepxml_file),
        "-rt",
        "2",
        "-s",
        str(mzml_file),
        "-st",
        "2",
        "-i",
        str(scan_file),
        "-k",
        "s",
        "-o",
        str(outdir),
        "-a",
        "0.05",
        "-c",
        "3",
        "-pw",
        "1",
        "-fw",
        "800",
        "-fh",
        "400",
        "-fu",
        "px",
        "-ft",
        "pdf",
    ]
    subprocess.run(cmd, check=True, cwd=pdv_jar.parent)


def main() -> None:
    args = parse_args()

    results_dir = Path(args.results_dir).resolve()
    mzml_directory = Path(args.mzml_directory).resolve()
    peptide_table = Path(args.target_peptide_table).resolve()
    pdv_jar = Path(args.pdv_jar).resolve()

    if not results_dir.exists():
        raise FileNotFoundError(f"Results directory not found: {results_dir}")
    if not mzml_directory.exists():
        raise FileNotFoundError(f"mzML directory not found: {mzml_directory}")
    if not peptide_table.exists():
        raise FileNotFoundError(f"Target peptide table not found: {peptide_table}")
    if not pdv_jar.exists():
        raise FileNotFoundError(f"PDV jar not found: {pdv_jar}")

    # In some CWL staging layouts, the passed results_dir may resolve to the
    # job root while the actual FragPipe results live in <root>/<basename>.
    staged_results_dir = results_dir / f"{args.output_basename}_results"
    if not results_dir.name.endswith("_results") and staged_results_dir.exists():
        results_dir = staged_results_dir

    target_peptides = read_target_peptides(peptide_table)
    psm_files = find_results_samples(results_dir)
    if not psm_files:
        raise FileNotFoundError(f"No psm.tsv files found under {results_dir}")

    mzml_index = index_mzml_files(mzml_directory)
    if not mzml_index:
        raise FileNotFoundError(f"No mzML files found under {mzml_directory}")

    base_output = results_dir / f"{args.output_basename}_pdv_spectra"
    base_output.mkdir(parents=True, exist_ok=True)

    summary_lines = [
        f"target_peptides\t{len(target_peptides)}",
        f"psm_files\t{len(psm_files)}",
    ]

    total_runs = 0
    total_scans = 0
    missing: dict[str, list[str]] = defaultdict(list)

    for psm_file in psm_files:
        sample_dir = psm_file.parent
        sample_name = sample_dir.name

        pepxml_file = select_pepxml(sample_dir)
        if pepxml_file is None:
            missing["missing_pepxml"].append(sample_name)
            continue

        mzml_file = mzml_index.get(sample_name)
        if mzml_file is None:
            missing["missing_mzml"].append(sample_name)
            continue

        scans = collect_scan_numbers(psm_file, target_peptides)
        if not scans:
            continue

        sample_outdir = base_output / sample_name
        sample_outdir.mkdir(parents=True, exist_ok=True)

        scan_file = sample_outdir / "spectrum_scan_number.txt"
        scan_file.write_text("\n".join(scans) + "\n", encoding="utf-8")

        run_pdv(
            pdv_jar=pdv_jar,
            pepxml_file=pepxml_file.resolve(),
            mzml_file=mzml_file.resolve(),
            scan_file=scan_file.resolve(),
            outdir=sample_outdir.resolve(),
        )

        total_runs += 1
        total_scans += len(scans)
        summary_lines.append(f"{sample_name}\t{len(scans)}")

    summary_lines.append(f"runs_with_plots\t{total_runs}")
    summary_lines.append(f"total_scans_submitted\t{total_scans}")

    for key, values in missing.items():
        summary_lines.append(f"{key}\t{','.join(sorted(values))}")

    summary_file = base_output / "pdv_summary.tsv"
    summary_file.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")

    print(f"PDV spectra directory: {base_output}")
    print(f"PDV summary: {summary_file}")


if __name__ == "__main__":
    main()
