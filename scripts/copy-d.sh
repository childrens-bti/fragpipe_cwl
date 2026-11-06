#!/usr/bin/env bash
set -euo pipefail


# Usage: copy-d.sh <SOURCE_DIR> [RUN_SUBSET] [SUBSET_PATTERN] <MANIFEST_FILE>
# Copy Bruker timsTOF .d directories and generate a FragPipe manifest.
# MSFragger reads .d natively, so no conversion is done.
SOURCE_DIR="$1"
RUN_SUBSET="${2:-false}"
SUBSET_PATTERN="$3"
MANIFEST_FILE="$4"
OUT_DIR="$(pwd)/mzml_files"

# Ensure output path is a directory
if [ -f "$OUT_DIR" ]; then
  rm -f "$OUT_DIR"
fi
mkdir -p "$OUT_DIR"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: mzml_source_dir does not exist: $SOURCE_DIR" >&2
  : > mzml_files.txt
  : > mzml_manifest.fp-manifest
  exit 1
fi

echo "run_subset is set to '$RUN_SUBSET'"
echo "subset_pattern is set to '$SUBSET_PATTERN'"
SOURCE_DIR_ABS="$(readlink -f "$SOURCE_DIR")"

# Process one .d directory: decide experiment, copy into per-experiment folder
process_dir() {
  local dpath="$1"

  # subset filter: only paths containing the subset pattern
  if [[ "$RUN_SUBSET" == "true" && "$dpath" != */$SUBSET_PATTERN/* ]]; then
    return 0
  fi

  local d_abs
  d_abs="$(readlink -f "$dpath")"

  # The directory containing the .d is the "experiment folder"
  local exp_src_dir
  exp_src_dir="$(dirname "$d_abs")"

  # Experiment id is the first directory under SOURCE_DIR, or SOURCE_DIR's own
  # name when .d folders sit directly under it (same rule as copy-mzml.sh)
  local exp_rel
  exp_rel="${exp_src_dir#"$SOURCE_DIR_ABS"/}"
  if [[ "$exp_rel" == "$exp_src_dir" ]]; then
    exp_rel="$(basename "$exp_src_dir")"
  fi
  local exp_name="${exp_rel%%/*}"
  [[ -n "$exp_name" ]] || exp_name="UNKNOWN_EXPERIMENT"

  local out_exp_dir="$OUT_DIR/$exp_name"
  mkdir -p "$out_exp_dir"

  echo "Copying $(basename "$d_abs") -> $out_exp_dir/"
  rm -rf "${out_exp_dir:?}/$(basename "$d_abs")"
  cp -r "$d_abs" "$out_exp_dir/"
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

# For each manifest base name, find the first matching .d directory under SOURCE_DIR
for m in "${!DATA_TYPE[@]}"; do
  d=$(find "$SOURCE_DIR" -type d -name "$m.d" -prune | head -n 1)
  if [[ -n "$d" ]]; then
    process_dir "$d"
  else
    echo "WARNING: No matching .d directory found for $m under $SOURCE_DIR" >&2
  fi
done

# Create mzml_files.txt (all .d paths)
find "$OUT_DIR" -mindepth 2 -maxdepth 2 -type d -name "*.d" | sort > mzml_files.txt

# mzml_manifest.fp-manifest: FragPipe format (path, basename without .d, empty, data type)
while IFS= read -r dpath; do
  basename=$(basename "$dpath" .d)
  echo -e "${dpath}\t${basename}\t\t${DATA_TYPE[$basename]:-DDA}"
done < mzml_files.txt > mzml_manifest.fp-manifest

echo "Copy complete. $(wc -l < mzml_files.txt) .d directories ready."
echo "Experiments found:"
find "$OUT_DIR" -mindepth 1 -maxdepth 1 -type d -printf "  %f\n" | sort
