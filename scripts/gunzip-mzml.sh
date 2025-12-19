#!/bin/bash
set -e
set -o pipefail

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
  touch mzml_files.txt
  exit 1
fi

# Find and decompress mzML files
echo "run_subset is set to '$RUN_SUBSET'"

if [ "$RUN_SUBSET" = "true" ]; then
  # Process only files in directories matching 01C pattern (checks full path)
  find "$SOURCE_DIR" -type f -name "*.mzML.gz" -print0 | \
    while IFS= read -r -d '' file; do
      # Check if the full path contains /01C
      if [[ "$file" == */01C* ]]; then
        echo "Decompressing $(basename "$file")"
        gunzip -c "$file" > "$OUT_DIR/$(basename "$file" .gz)"
        
        # Copy annotation.txt file from the same directory if it exists
        source_dir=$(dirname "$file")
        if [ -f "$source_dir/annotation.txt" ] && [ ! -f "$OUT_DIR/annotation.txt" ]; then
          echo "Copying annotation.txt from $(basename "$source_dir")"
          cp "$source_dir/annotation.txt" "$OUT_DIR/annotation.txt"
        fi
      fi
    done
else
  # Process all mzML.gz files
  find "$SOURCE_DIR" -name "*.mzML.gz" -print0 | \
    while IFS= read -r -d '' file; do
      echo "Decompressing $(basename "$file")"
      gunzip -c "$file" > "$OUT_DIR/$(basename "$file" .gz)"
      
      # Copy annotation.txt file from the same directory if it exists
      source_dir=$(dirname "$file")
      if [ -f "$source_dir/annotation.txt" ] && [ ! -f "$OUT_DIR/annotation.txt" ]; then
        echo "Copying annotation.txt from $(basename "$source_dir")"
        cp "$source_dir/annotation.txt" "$OUT_DIR/annotation.txt"
      fi
    done
fi

# Create manifest files
# mzml_files.txt: simple list of paths
find "$OUT_DIR" -name "*.mzML" | sort > mzml_files.txt

# mzml_manifest.fp-manifest: FragPipe format (path + tabs + DDA)
while IFS= read -r filepath; do
  echo -e "${filepath}\t\t\tDDA"
done < mzml_files.txt > mzml_manifest.fp-manifest

touch mzml_files.txt mzml_manifest.fp-manifest
echo "Decompression complete. $(wc -l < mzml_files.txt) files ready."
