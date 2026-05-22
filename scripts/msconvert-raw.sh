#!/usr/bin/env bash
set -euo pipefail

# Always isolate Wine per worker so restarted tasks never contend on /tmp/.wine-<uid>.
CURRENT_UID=$(id -u)
WINEPREFIX_OWNER_UID=$(stat -c '%u' /wineprefix64 2>/dev/null || echo "unknown")
echo "Using per-worker Wine isolation (current uid: $CURRENT_UID, owner uid: $WINEPREFIX_OWNER_UID)"

export WINEARCH=win64
export WINEDEBUG=-all

# Usage: msconvert-raw.sh <SOURCE_DIR> <RUN_SUBSET> <SUBSET_PATTERN> <MANIFEST_FILE> [NUM_CORES]
SOURCE_DIR="$1"
RUN_SUBSET="$2"
SUBSET_PATTERN="$3"
MANIFEST_FILE="$4"
NUM_CORES="${5:-8}"  # Fallback when 5th arg is not provided
OUT_DIR="$(pwd)/mzml_files"

# Ensure output path is a directory
if [ -f "$OUT_DIR" ]; then
  rm -f "$OUT_DIR"
fi
mkdir -p "$OUT_DIR"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: Source directory not found: $SOURCE_DIR" >&2
  : > mzml_files.txt
  : > mzml_manifest.fp-manifest
  exit 1
fi

echo "=== Converting .raw files to mzML ==="
echo "Source directory: $SOURCE_DIR"
echo "Run subset: $RUN_SUBSET"
echo "Subset pattern: $SUBSET_PATTERN"
echo "Parallel jobs: $NUM_CORES"

SOURCE_DIR_ABS="$(readlink -f "$SOURCE_DIR")"

# Process one .raw file: convert to mzML preserving experiment folder structure
process_file() {
  local file="$1"
  local worker_wineprefix=""
  local worker_tmpdir=""

  worker_tmpdir="$(mktemp -d /tmp/wine-tmp.XXXXXX)"
  worker_wineprefix="$(mktemp -d /tmp/wineprefix.XXXXXX)"

  if [ -d /wineprefix64 ]; then
    cp -r /wineprefix64/. "$worker_wineprefix" 2>/dev/null || {
      echo "WARNING: Could not copy /wineprefix64 for worker, using fresh prefix"
    }
  fi

  cleanup_worker_wine() {
    rm -rf "$worker_wineprefix" "$worker_tmpdir" 2>/dev/null || true
  }
  trap cleanup_worker_wine RETURN

  # subset filter: only paths containing the subset pattern
  if [[ "$RUN_SUBSET" == "true" && "$file" != */$SUBSET_PATTERN/* ]]; then
    return 0
  fi

  local file_abs
  file_abs="$(readlink -f "$file")"

  # Get experiment folder structure
  local exp_src_dir
  exp_src_dir="$(dirname "$file_abs")"

  # Define experiment id as the directory under SOURCE_DIR
  local exp_rel
  exp_rel="${exp_src_dir#"$SOURCE_DIR_ABS"/}"
  if [[ "$exp_rel" == "$exp_src_dir" ]]; then
    exp_rel="$(basename "$exp_src_dir")"
  fi

  local exp_name="${exp_rel%%/*}"
  [[ -n "$exp_name" ]] || exp_name="UNKNOWN_EXPERIMENT"

  local out_exp_dir="$OUT_DIR/$exp_name"
  mkdir -p "$out_exp_dir"

  # Convert .raw to mzML
  local basename_no_ext
  basename_no_ext=$(basename "$file" .raw)
  basename_no_ext=$(basename "$basename_no_ext" .RAW)
  
  local mzml_out="$out_exp_dir/${basename_no_ext}.mzML"
  local log_file="$out_exp_dir/${basename_no_ext}.log"

  if [ -f "$mzml_out" ]; then
    echo "Already exists: $mzml_out"
  else
    echo "Converting: $file -> $mzml_out"
    TMPDIR="$worker_tmpdir" XDG_RUNTIME_DIR="$worker_tmpdir" WINEPREFIX="$worker_wineprefix" wine msconvert --64 --zlib \
      --filter "peakPicking" \
      --filter "zeroSamples removeExtra 1-" \
      --outdir "$out_exp_dir" \
      "$file" > "$log_file" 2>&1 || {
        echo "ERROR: Conversion failed for $file (see $log_file)" >&2
        cat "$log_file" >&2
        exit 1
      }
  fi

  # Copy annotation if present
  if [ -f "$exp_src_dir/annotation.txt" ]; then
    annotation_dst="$out_exp_dir/annotation.txt"
    awk 'BEGIN{IGNORECASE=1}
         { sub(/\r$/, "") }
         /^[[:space:]]*#/ { next }
         /^[[:space:]]*$/ { next }
         tolower($1)=="channel" && tolower($2)=="sample" { next }
         { print }' "$exp_src_dir/annotation.txt" > "$annotation_dst" 2>/dev/null || true
    if ! awk -F'\t' 'NF >= 2 { ok=1; exit } END { exit(ok ? 0 : 1) }' "$annotation_dst" 2>/dev/null; then
      cp "$exp_src_dir/annotation.txt" "$annotation_dst" 2>/dev/null || true
    fi
  fi
}

# Export variables and function for parallel
export SOURCE_DIR_ABS OUT_DIR RUN_SUBSET SUBSET_PATTERN CURRENT_UID WINEPREFIX_OWNER_UID
export -f process_file

# Read manifest and collect files to process
FILES_TO_PROCESS=()
while IFS=$'\t' read -r path_ignored exp_name rest; do
  [[ -z "$exp_name" || "$exp_name" == "Experiment"* ]] && continue
  
  # Find .raw file matching the base name.
  # Use -L to follow symlinks: CWL stages directory contents as symlinks under /var/lib/cwl/stg*.
  found_files=$(find -L "$SOURCE_DIR_ABS" -type f -iname "${exp_name}.raw" 2>/dev/null || true)
  
  if [ -z "$found_files" ]; then
    echo "WARNING: No .raw file found for $exp_name"
    continue
  fi
  
  while IFS= read -r raw_file; do
    FILES_TO_PROCESS+=("$raw_file")
  done <<< "$found_files"
done < "$MANIFEST_FILE"

# Process files in parallel using GNU parallel or xargs
if command -v parallel &> /dev/null; then
  echo "Using GNU parallel with $NUM_CORES jobs"
  printf '%s\n' "${FILES_TO_PROCESS[@]}" | parallel -j "$NUM_CORES" process_file
else
  echo "Using xargs with $NUM_CORES jobs (GNU parallel not available)"
  printf '%s\n' "${FILES_TO_PROCESS[@]}" | xargs -P "$NUM_CORES" -I {} bash -c 'process_file "$@"' _ {}
fi

# Generate file list
find "$OUT_DIR" -type f \( -name "*.mzML" -o -name "*.mzml" \) | sort > mzml_files.txt

# Generate FragPipe manifest
> mzml_manifest.fp-manifest
while IFS= read -r mzml_file; do
  basename_no_ext=$(basename "$mzml_file" .mzML)
  basename_no_ext=$(basename "$basename_no_ext" .mzml)
  echo -e "${mzml_file}\t${basename_no_ext}\t\tDDA" >> mzml_manifest.fp-manifest
done < mzml_files.txt

NUM_FILES=$(wc -l < mzml_files.txt)
echo "=== Converted $NUM_FILES files ==="
