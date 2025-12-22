#!/bin/bash
set -e
set -o pipefail

FILTERED_FASTA="$1"
WORKFLOW_FILE="$2"
MANIFEST_FILE="$3"


# Set up writable runtime directory and HOME for FragPipe config/cache
RUNTIME_DIR="$(pwd)/fragpipe-runtime"
FRAGPIPE_SRC="/fragpipe_bin/fragPipe-22.0/fragpipe"
if [ ! -d "$RUNTIME_DIR" ]; then
  cp -R "$FRAGPIPE_SRC" "$RUNTIME_DIR"
fi
export HOME="$RUNTIME_DIR"
mkdir -p "$HOME/.config/FragPipe" "$HOME/.cache"

FRAGPIPE_BIN="$RUNTIME_DIR/bin/fragpipe"
FRAGPIPE_TOOLS="$RUNTIME_DIR/tools"

# Get absolute path to FASTA for FragPipe
FASTA_ABS="$(cd "$(dirname "$FILTERED_FASTA")" && pwd)/$(basename "$FILTERED_FASTA")"

# Create modified workflow file with correct FASTA path
WORKFLOW_MODIFIED="$(pwd)/workflow_modified.workflow"
sed "s|database.db-path=.*|database.db-path=$FASTA_ABS|g" "$WORKFLOW_FILE" > "$WORKFLOW_MODIFIED"

# Run FragPipe in headless mode
"$FRAGPIPE_BIN" \
  --headless \
  --workflow "$WORKFLOW_MODIFIED" \
  --manifest "$MANIFEST_FILE" \
  --workdir "$(pwd)/results" \
  --config-tools-folder "$FRAGPIPE_TOOLS"
