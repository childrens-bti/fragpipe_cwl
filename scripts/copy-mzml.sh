#!/usr/bin/env bash
set -euo pipefail


# Usage: copy-mzml.sh <SOURCE_DIR> [RUN_SUBSET] [SUBSET_PATTERN] <MANIFEST_FILE>
# Copy uncompressed mzML files and perform other setup steps (annotation, manifest)
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

# Process one mzML file: decide experiment, copy annotation, copy into per-experiment folder
process_file() {
  local file="$1"

  # subset filter: only paths containing the subset pattern
  if [[ "$RUN_SUBSET" == "true" && "$file" != */$SUBSET_PATTERN/* ]]; then
    return 0
  fi

  local file_abs
  file_abs="$(readlink -f "$file")"

  # The directory containing the mzML is the "experiment folder"
  local exp_src_dir
  exp_src_dir="$(dirname "$file_abs")"

  # Try to define experiment id as the directory under SOURCE_DIR (relative path)
  # Example: SOURCE_DIR=/data/platform ; exp_src_dir=/data/platform/Exp1  => exp_rel=Exp1
  local exp_rel
  exp_rel="${exp_src_dir#"$SOURCE_DIR_ABS"/}"
  if [[ "$exp_rel" == "$exp_src_dir" ]]; then
    # not under SOURCE_DIR for some reason; fallback to basename
    exp_rel="$(basename "$exp_src_dir")"
  fi

  # If exp_rel contains subdirs (e.g. Exp1/subdir), use the first component as experiment name
  local exp_name="${exp_rel%%/*}"
  [[ -n "$exp_name" ]] || exp_name="UNKNOWN_EXPERIMENT"

  local out_exp_dir="$OUT_DIR/$exp_name"
  mkdir -p "$out_exp_dir"

  # Copy annotation.txt for THIS experiment into its folder (only once)
  if [[ -f "$exp_src_dir/annotation.txt" && ! -f "$out_exp_dir/annotation.txt" ]]; then
    echo "Copying annotation.txt for experiment '$exp_name' from $exp_src_dir"
    cp -f "$exp_src_dir/annotation.txt" "$out_exp_dir/annotation.txt"
  fi

  echo "Copying $(basename "$file_abs") -> $out_exp_dir/"
  cp -f "$file_abs" "$out_exp_dir/$(basename "$file_abs")"
}

export -f process_file
export RUN_SUBSET OUT_DIR SOURCE_DIR_ABS


# Manifest file is required
if [[ -z "$MANIFEST_FILE" || ! -f "$MANIFEST_FILE" ]]; then
  echo "ERROR: Manifest file is required and was not found: $MANIFEST_FILE" >&2
  exit 2
fi
echo "Using manifest file: $MANIFEST_FILE"

# Read base names (col2) and acquisition mode (col4) from the manifest.
# Use awk to preserve true column positions even when col3 is empty.
declare -A MANIFEST_ACQ_MODE
while IFS=$'\t' read -r base acq; do
  [[ -n "$base" ]] || continue
  acq="${acq%$'\r'}"
  if [[ -z "$acq" ]]; then
    acq="DDA"
  fi
  MANIFEST_ACQ_MODE["$base"]="$acq"
done < <(awk -F'\t' 'NF >= 2 {print $2 "\t" $4}' "$MANIFEST_FILE")

mapfile -t MANIFEST_BASENAMES < <(printf '%s\n' "${!MANIFEST_ACQ_MODE[@]}" | sort)
# Process files found either directly under SOURCE_DIR or in experiment subfolders
# For each manifest base name, find the first matching file anywhere under SOURCE_DIR
for m in "${MANIFEST_BASENAMES[@]}"; do
  # Find the first match under SOURCE_DIR (top-level or nested)
  f=$(find "$SOURCE_DIR" -type f -name "$m.mzML" | head -n 1)
  if [[ -n "$f" ]]; then
    process_file "$f"
  else
    echo "WARNING: No matching mzML found for $m under $SOURCE_DIR" >&2
  fi
done

# Create mzml_files.txt (all mzML paths)
find "$OUT_DIR" -type f -name "*.mzML" | sort > mzml_files.txt

# mzml_manifest.fp-manifest: FragPipe format (path, basename without .mzML, empty, acquisition mode)
while IFS= read -r filepath; do
  basename=$(basename "$filepath" .mzML)
  acq="${MANIFEST_ACQ_MODE[$basename]:-DDA}"
  echo -e "${filepath}\t${basename}\t\t${acq}"
done < mzml_files.txt > mzml_manifest.fp-manifest

echo "Copy complete. $(wc -l < mzml_files.txt) mzML files ready."
echo "Experiments found:"
find "$OUT_DIR" -mindepth 1 -maxdepth 1 -type d -printf "  %f\n" | sort
