#!/usr/bin/env python3
import sys
import pandas as pd


def is_non_canonical(protein_series: pd.Series) -> pd.Series:
    values = protein_series.fillna("").astype(str).str.strip()
    return ~(values.str.startswith("sp|") | values.str.startswith("tr|"))


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit(
            "Usage: filter-control-peptides.py <input_combined_peptide.tsv> "
            "<control_combined_peptide.tsv> <output_basename>"
        )

    input_path = sys.argv[1]
    control_path = sys.argv[2]
    output_basename = sys.argv[3]

    filtered_output = f"{output_basename}_combined_peptide_control_filtered.tsv"
    summary_output = f"{output_basename}_control_overlap_summary.txt"

    peptide_col = "Peptide Sequence"
    protein_col = "Protein"

    control_df = pd.read_csv(control_path, sep="\t", dtype=str, keep_default_na=False)
    if peptide_col not in control_df.columns or protein_col not in control_df.columns:
        raise ValueError(f"Control file must contain columns: '{peptide_col}', '{protein_col}'")

    control_protein = control_df[protein_col]
    control_tumor_mask = is_non_canonical(control_protein)
    control_peptides = set(
        control_df.loc[control_tumor_mask, peptide_col]
        .astype(str)
        .str.strip()
        .loc[lambda series: series.ne("")]
        .unique()
        .tolist()
    )

    input_df = pd.read_csv(input_path, sep="\t", dtype=str, keep_default_na=False)
    if peptide_col not in input_df.columns or protein_col not in input_df.columns:
        raise ValueError(f"Input file must contain columns: '{peptide_col}', '{protein_col}'")

    input_protein = input_df[protein_col]
    input_tumor_mask = is_non_canonical(input_protein)
    input_peptides = input_df[peptide_col].astype(str).str.strip()
    overlap_mask = input_peptides.ne("") & input_peptides.isin(control_peptides)

    keep_mask = input_tumor_mask & ~overlap_mask
    filtered_df = input_df.loc[keep_mask].copy()
    filtered_df.to_csv(filtered_output, sep="\t", index=False)

    input_total_peptides = int(input_peptides.ne("").sum())
    input_tumor_specific_peptides = int((input_tumor_mask & input_peptides.ne("")).sum())

    control_peptide_series = control_df[peptide_col].astype(str).str.strip()
    control_total_peptides = int(control_peptide_series.ne("").sum())
    control_tumor_specific_peptides = int((control_tumor_mask & control_peptide_series.ne("")).sum())

    removed_rows = int((input_tumor_mask & overlap_mask).sum())
    kept_rows = int(keep_mask.sum())

    with open(summary_output, "w") as summary_handle:
        summary_handle.write(f"input_total_peptides\t{input_total_peptides}\n")
        summary_handle.write(
            f"input_tumor_specific_peptides\t{input_tumor_specific_peptides}\n"
        )
        summary_handle.write(f"control_total_peptides\t{control_total_peptides}\n")
        summary_handle.write(
            f"control_tumor_specific_peptides\t{control_tumor_specific_peptides}\n"
        )
        summary_handle.write(f"tumor_specific_overlap_filtered\t{removed_rows}\n")
        summary_handle.write(f"final_peptides_left\t{kept_rows}\n")

    print(f"Filtered combined peptide file: {filtered_output}")
    print(f"Summary: {summary_output}")


if __name__ == "__main__":
    main()