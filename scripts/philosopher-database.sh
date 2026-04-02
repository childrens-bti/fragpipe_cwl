#!/bin/bash
set -e
set -o pipefail

QUERY_FASTA="$1"
UNIPROT_FASTA="$2"

PHIL_BIN="/fragpipe_bin/fragPipe-22.0/fragpipe/tools/Philosopher/philosopher-v5.1.1"

# Initialize Philosopher workspace
"$PHIL_BIN" workspace --init

# Add decoys and contaminants to the custom FASTA file
# Handle both gzipped and uncompressed files
if [[ "$UNIPROT_FASTA" == *.gz ]]; then
  gunzip -c "$UNIPROT_FASTA"
else
  cat "$UNIPROT_FASTA"
fi | "$PHIL_BIN" database \
    --custom "$QUERY_FASTA" \
    --add /dev/stdin \
    --contam

# Find the output file (philosopher adds decoys-contam prefix)
output_file=$(ls *decoys-contam-*.fas 2>/dev/null | head -1)

if [ -z "$output_file" ]; then
  echo "Error: Output file not found" >&2
  exit 1
fi

# Copy to expected output name
cp "$output_file" decoys-contam-custom.fasta.fas

# Clean workspace
# "$PHIL_BIN" workspace --clean
