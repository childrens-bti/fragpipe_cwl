#!/bin/bash
set -e
set -o pipefail

QUERY_FASTA="$1"
UNIPROT_FASTA="$2"

# Initialize Philosopher workspace
philosopher workspace --init

# Add decoys and contaminants to the custom FASTA file
gunzip -c "$UNIPROT_FASTA" | \
  philosopher database \
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
philosopher workspace --clean
