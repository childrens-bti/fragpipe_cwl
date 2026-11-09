#!/usr/bin/env bash
set -euo pipefail


# Usage: extract-d.sh <SOURCE_DIR> [RUN_SUBSET] [SUBSET_PATTERN] <MANIFEST_FILE>
# Extract Bruker timsTOF runs from <run>.d.zip, .d.tar, .d.tar.gz or .d.tgz
# archives and generate a FragPipe manifest. Each archive must hold <run>.d/
# at its root. MSFragger reads .d natively, so no conversion is done.
SOURCE_DIR="$1"
RUN_SUBSET="${2:-false}"
SUBSET_PATTERN="$3"
MANIFEST_FILE="$4"
OUT_DIR="$(pwd)/input_files"

# Ensure output path is a directory
if [ -f "$OUT_DIR" ]; then
  rm -f "$OUT_DIR"
fi
mkdir -p "$OUT_DIR"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: input_source_dir does not exist: $SOURCE_DIR" >&2
  : > input_files.txt
  : > input_manifest.fp-manifest
  exit 1
fi

echo "run_subset is set to '$RUN_SUBSET'"
echo "subset_pattern is set to '$SUBSET_PATTERN'"
SOURCE_DIR_ABS="$(readlink -f "$SOURCE_DIR")"

# Process one .d archive: decide experiment, extract into per-experiment folder
process_archive() {
  local dpath="$1"
  local run="$2"

  # subset filter: only paths containing the subset pattern
  if [[ "$RUN_SUBSET" == "true" && "$dpath" != */$SUBSET_PATTERN/* ]]; then
    return 0
  fi

  local d_abs
  d_abs="$(readlink -f "$dpath")"

  # The directory containing the archive is the "experiment folder"
  local exp_src_dir
  exp_src_dir="$(dirname "$d_abs")"

  # Experiment id is the first directory under SOURCE_DIR, or SOURCE_DIR's own
  # name when archives sit directly under it (same rule as copy-mzml.sh)
  local exp_rel
  exp_rel="${exp_src_dir#"$SOURCE_DIR_ABS"/}"
  if [[ "$exp_rel" == "$exp_src_dir" ]]; then
    exp_rel="$(basename "$exp_src_dir")"
  fi
  local exp_name="${exp_rel%%/*}"
  [[ -n "$exp_name" ]] || exp_name="UNKNOWN_EXPERIMENT"

  local out_exp_dir="$OUT_DIR/$exp_name"
  mkdir -p "$out_exp_dir"

  rm -rf "${out_exp_dir:?}/$run.d"
  extract_archive "$d_abs" "$run" "$out_exp_dir"
}

# Extract <run>.d.{zip,tar,tar.gz,tgz} and check it holds a single <run>.d/
extract_archive() {
  local archive="$1"
  local run="$2"
  local out_exp_dir="$3"
  local staging="$out_exp_dir/.extract_$run"

  echo "Extracting $(basename "$archive") -> $out_exp_dir/"
  rm -rf "$staging"
  mkdir -p "$staging"
  case "$archive" in
    *.zip) unzip -q "$archive" -d "$staging" ;;
    *)     tar -xf "$archive" -C "$staging" ;;
  esac
  rm -rf "$staging/__MACOSX"

  local entries
  entries=$(find "$staging" -mindepth 1 -maxdepth 1 | wc -l)
  if [[ "$entries" -ne 1 || ! -d "$staging/$run.d" ]]; then
    echo "ERROR: $(basename "$archive") must contain a single top-level $run.d/ directory" >&2
    find "$staging" -mindepth 1 -maxdepth 1 -printf "  found: %f\n" >&2
    exit 3
  fi
  if [[ ! -f "$staging/$run.d/analysis.tdf" ]]; then
    echo "ERROR: $run.d from $(basename "$archive") has no analysis.tdf (not a timsTOF .d run)" >&2
    exit 3
  fi
  mv "$staging/$run.d" "$out_exp_dir/"
  rm -rf "$staging"
}


# Manifest file is required
if [[ -z "$MANIFEST_FILE" || ! -f "$MANIFEST_FILE" ]]; then
  echo "ERROR: Manifest file is required and was not found: $MANIFEST_FILE" >&2
  exit 2
fi
echo "Using manifest file: $MANIFEST_FILE"
# Read base names (2nd column) and optional data type (4th column, default DDA)
declare -A DATA_TYPE
while IFS=$'\t' read -r base dtype; do
  DATA_TYPE["$base"]="$dtype"
done < <(awk -F'\t' '{ sub(/\r$/, "") } $2 != "" { print $2 "\t" ($4 != "" ? $4 : "DDA") }' "$MANIFEST_FILE")

# For each manifest base name, find the first matching .d archive under SOURCE_DIR
for m in "${!DATA_TYPE[@]}"; do
  d=$(find "$SOURCE_DIR" -type f \( -name "$m.d.zip" -o -name "$m.d.tar" -o -name "$m.d.tar.gz" -o -name "$m.d.tgz" \) | sort | head -n 1)
  if [[ -n "$d" ]]; then
    process_archive "$d" "$m"
  else
    echo "WARNING: No matching .d.zip/.d.tar/.d.tar.gz/.d.tgz archive found for $m under $SOURCE_DIR" >&2
  fi
done

# Create input_files.txt (all extracted .d paths)
find "$OUT_DIR" -mindepth 2 -maxdepth 2 -type d -name "*.d" | sort > input_files.txt

# input_manifest.fp-manifest: FragPipe format (path, basename without .d, empty, data type)
while IFS= read -r dpath; do
  basename=$(basename "$dpath" .d)
  echo -e "${dpath}\t${basename}\t\t${DATA_TYPE[$basename]:-DDA}"
done < input_files.txt > input_manifest.fp-manifest

echo "Extraction complete. $(wc -l < input_files.txt) .d directories ready."
echo "Experiments found:"
find "$OUT_DIR" -mindepth 1 -maxdepth 1 -type d -printf "  %f\n" | sort
