#!/bin/bash
set -e
set -o pipefail

FILTERED_FASTA="$1"
WORKFLOW_FILE="$2"
MANIFEST_FILE="$3"

# Run FragPipe in headless mode
fragpipe \
  --headless \
  --workflow "$WORKFLOW_FILE" \
  --manifest "$MANIFEST_FILE" \
  --workdir "$(pwd)/results" \
  --config-tools-folder /fragpipe_bin/fragpipe-23.1/tools
