#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$1"
RUN_SUBSET="${2:-false}"
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
SOURCE_DIR_ABS="$(readlink -f "$SOURCE_DIR")"

# Process one mzML.gz file: decide experiment, copy annotation, gunzip into per-experiment folder
process_file() {
  local file="$1"

  # subset filter: only paths containing /01C
  if [[ "$RUN_SUBSET" == "true" && "$file" != */01C* ]]; then
    return 0
  fi

  local file_abs
  file_abs="$(readlink -f "$file")"

  # The directory containing the mzML.gz is the "experiment folder"
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

  echo "Decompressing $(basename "$file_abs") -> $out_exp_dir/"
  gunzip -c "$file_abs" > "$out_exp_dir/$(basename "$file_abs" .gz)"
}

export -f process_file
export RUN_SUBSET OUT_DIR SOURCE_DIR_ABS

# Find and decompress
while IFS= read -r -d '' f; do
  process_file "$f"
done < <(find "$SOURCE_DIR" -type f -name "*.mzML.gz" -print0)

# Create mzml_files.txt (all mzML paths)
find "$OUT_DIR" -type f -name "*.mzML" | sort > mzml_files.txt

# Create mzml_manifest.fp-manifest
# Format here: <path>\t<experiment>\t\tDDA
# (2nd col = experiment/group so FragPipe separates outputs by experiment)
: > mzml_manifest.fp-manifest
while IFS= read -r filepath; do
  exp="$(basename "$(dirname "$filepath")")"
  echo -e "${filepath}\t${exp}\t\tDDA"
done < mzml_files.txt >> mzml_manifest.fp-manifest

echo "Decompression complete. $(wc -l < mzml_files.txt) mzML files ready."
echo "Experiments found:"
find "$OUT_DIR" -mindepth 1 -maxdepth 1 -type d -printf "  %f\n" | sort
