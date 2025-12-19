#!/bin/bash
set -e
set -o pipefail

FILTERED_FASTA="$1"
WORKFLOW_FILE="$2"
MANIFEST_FILE="$3"

# Copy FragPipe install into writable working directory and set writable HOME for config/cache
FRAGPIPE_SRC="/fragpipe_bin/fragPipe-22.0/fragpipe"
FRAGPIPE_RUNTIME="$(pwd)/fragpipe-runtime"
if [ ! -d "$FRAGPIPE_RUNTIME" ]; then
  cp -R "$FRAGPIPE_SRC" "$FRAGPIPE_RUNTIME"
fi
mkdir -p "$FRAGPIPE_RUNTIME/cache"

FRAGPIPE_BIN="$FRAGPIPE_RUNTIME/bin/fragpipe"
FRAGPIPE_TOOLS="$FRAGPIPE_RUNTIME/tools"

# Ensure FragPipe config directory exists (HOME set to runtime.outdir by CWL)
mkdir -p "$HOME/.config/FragPipe" "$HOME/.cache"

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
