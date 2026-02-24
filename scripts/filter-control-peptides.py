#!/usr/bin/env python3
import sys
import re
import pandas as pd


def is_non_canonical(protein_series: pd.Series) -> pd.Series:
    values = protein_series.fillna("").astype(str).str.strip()
    is_decoy = values.str.startswith("rev_")
    is_canonical = values.str.startswith("sp|") | values.str.startswith("tr|")
    return ~is_decoy & ~is_canonical


def parse_mutation_position(protein_value: str) -> int | None:
    text = str(protein_value)
    pept_match = re.search(r"peptMutPos=(\d+)", text)
    if pept_match:
        return int(pept_match.group(1))
    fusion_match = re.search(r"Protein_fusion_site:(\d+)", text)
    if fusion_match:
        return int(fusion_match.group(1))
    return None


def is_splice_event_id(protein_value: str) -> bool:
    text = str(protein_value).strip()
    return bool(
        re.match(
            r"^>?chr[^:]+:(?:\d+-\d+_\d+-\d+|\d+_\d+)_.+_phase[0-2]$",
            text,
        )
    )


def overlaps_mutation_site(start_value: str, end_value: str, mutation_pos: int | None) -> bool:
    if mutation_pos is None:
        return False
    try:
        start = int(float(start_value))
        end = int(float(end_value))
    except (TypeError, ValueError):
        return False
    if start > end:
        start, end = end, start
    return start <= mutation_pos <= end


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
    input_tumor_specific_output = f"{output_basename}_input_tumor_specific_peptides.tsv"
    control_tumor_specific_output = f"{output_basename}_control_tumor_specific_peptides.tsv"

    peptide_col = "Peptide Sequence"
    protein_col = "Protein"
    start_col = "Start"
    end_col = "End"

    control_df = pd.read_csv(control_path, sep="\t", dtype=str, keep_default_na=False)
    required_control_cols = [peptide_col, protein_col, start_col, end_col]
    missing_control_cols = [col for col in required_control_cols if col not in control_df.columns]
    if missing_control_cols:
        raise ValueError(
            "Control file must contain columns: "
            + ", ".join(f"'{col}'" for col in required_control_cols)
        )

    control_protein = control_df[protein_col]
    control_peptide_series = control_df[peptide_col].astype(str).str.strip()
    control_tumor_base_mask = is_non_canonical(control_protein) & control_peptide_series.ne("")

    control_mutation_overlap_mask = pd.Series(True, index=control_df.index)
    for idx, row in control_df.loc[
        control_tumor_base_mask, [protein_col, start_col, end_col]
    ].iterrows():
        protein_value = row[protein_col]
        if is_splice_event_id(protein_value):
            control_mutation_overlap_mask.at[idx] = True
            continue
        mutation_pos = parse_mutation_position(protein_value)
        if mutation_pos is not None:
            control_mutation_overlap_mask.at[idx] = overlaps_mutation_site(
                row[start_col], row[end_col], mutation_pos
            )
        else:
            control_mutation_overlap_mask.at[idx] = True

    control_tumor_mask = control_tumor_base_mask & control_mutation_overlap_mask
    control_peptides = set(
        control_df.loc[control_tumor_mask, peptide_col]
        .astype(str)
        .str.strip()
        .loc[lambda series: series.ne("")]
        .unique()
        .tolist()
    )
    control_peptide_list = list(control_peptides)

    input_df = pd.read_csv(input_path, sep="\t", dtype=str, keep_default_na=False)
    required_input_cols = [peptide_col, protein_col, start_col, end_col]
    missing_input_cols = [col for col in required_input_cols if col not in input_df.columns]
    if missing_input_cols:
        raise ValueError(
            "Input file must contain columns: "
            + ", ".join(f"'{col}'" for col in required_input_cols)
        )

    input_protein = input_df[protein_col]
    input_peptides = input_df[peptide_col].astype(str).str.strip()
    input_tumor_base_mask = is_non_canonical(input_protein) & input_peptides.ne("")
    input_tumor_specific_mask = input_tumor_base_mask.copy()

    mutation_overlap_mask = pd.Series(True, index=input_df.index)
    for idx, row in input_df.loc[input_tumor_base_mask, [protein_col, start_col, end_col]].iterrows():
        protein_value = row[protein_col]
        if is_splice_event_id(protein_value):
            mutation_overlap_mask.at[idx] = True
            continue
        mutation_pos = parse_mutation_position(protein_value)
        if mutation_pos is not None:
            mutation_overlap_mask.at[idx] = overlaps_mutation_site(
                row[start_col], row[end_col], mutation_pos
            )
        else:
            mutation_overlap_mask.at[idx] = True

    input_tumor_specific_mask = input_tumor_base_mask & mutation_overlap_mask
    overlap_mask = pd.Series(False, index=input_df.index)
    candidate_mask = input_tumor_specific_mask

    for idx, peptide in input_peptides.loc[candidate_mask].items():
        has_overlap = any(
            peptide == control_peptide
            or peptide in control_peptide
            or control_peptide in peptide
            for control_peptide in control_peptide_list
        )
        if has_overlap:
            overlap_mask.at[idx] = True

    keep_mask = input_tumor_specific_mask & ~overlap_mask
    filtered_df = input_df.loc[keep_mask].copy()
    filtered_df.to_csv(filtered_output, sep="\t", index=False)
    input_df.loc[input_tumor_specific_mask].copy().to_csv(
        input_tumor_specific_output, sep="\t", index=False
    )
    input_total_peptides = int(input_peptides.ne("").sum())
    input_tumor_specific_peptides = int(input_tumor_specific_mask.sum())

    control_tumor_specific_mask = control_tumor_mask
    control_df.loc[control_tumor_specific_mask].copy().to_csv(
        control_tumor_specific_output, sep="\t", index=False
    )
    control_total_peptides = int(control_peptide_series.ne("").sum())
    control_tumor_specific_peptides = int(control_tumor_specific_mask.sum())

    removed_rows = int((input_tumor_specific_mask & overlap_mask).sum())
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
    print(f"Input tumor-specific peptides file: {input_tumor_specific_output}")
    print(f"Control tumor-specific peptides file: {control_tumor_specific_output}")
    print(f"Summary: {summary_output}")


if __name__ == "__main__":
    main()