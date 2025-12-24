#!/bin/bash
set -e
set -o pipefail

FILTERED_FASTA="$1"
WORKFLOW_FILE="$2"
MANIFEST_FILE="$3"
RESULTS_DIR="$4"


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
RESULTS_DIR="${RESULTS_DIR:-results}"
RESULTS_DIR="$(cd "$(pwd)" && echo "$(pwd)/$RESULTS_DIR")"
mkdir -p "$RESULTS_DIR"

# Get absolute path to FASTA for FragPipe
FASTA_ABS="$(cd "$(dirname "$FILTERED_FASTA")" && pwd)/$(basename "$FILTERED_FASTA")"

# Create modified workflow file with correct FASTA path
WORKFLOW_MODIFIED="$(pwd)/workflow_modified.workflow"
sed "s|database.db-path=.*|database.db-path=$FASTA_ABS|g" "$WORKFLOW_FILE" > "$WORKFLOW_MODIFIED"

# Run FragPipe in headless mode
LOG_FILE="$RESULTS_DIR/log_$(date +%Y%m%d_%H%M%S).txt"
"$FRAGPIPE_BIN" \
  --headless \
  --workflow "$WORKFLOW_MODIFIED" \
  --manifest "$MANIFEST_FILE" \
  --workdir "$RESULTS_DIR" \
  --config-tools-folder "$FRAGPIPE_TOOLS" \
  2>&1 | tee "$LOG_FILE"
