#!/bin/bash
set -e
set -o pipefail

FILTERED_FASTA="$1"
WORKFLOW_FILE="$2"
MANIFEST_FILE="$3"
OUTPUT_BASENAME="$4"

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
RESULTS_DIR="${OUTPUT_BASENAME}_results"
RESULTS_DIR="$(cd "$(pwd)" && echo "$(pwd)/$RESULTS_DIR")"
mkdir -p "$RESULTS_DIR"

# Get absolute path to FASTA for FragPipe
FASTA_ABS="$(cd "$(dirname "$FILTERED_FASTA")" && pwd)/$(basename "$FILTERED_FASTA")"

# Create modified workflow file with correct FASTA path
WORKFLOW_MODIFIED="$(pwd)/workflow_modified.workflow"
awk -v db="database.db-path=$FASTA_ABS" 'BEGIN{done=0} /^database\.db-path=/{if(!done){print db; done=1}; next} {print} END{if(!done) print db}' "$WORKFLOW_FILE" > "$WORKFLOW_MODIFIED"

# Run FragPipe in headless mode (FragPipe writes its own log file in the workdir)
RUN_LOG="$(pwd)/fragpipe-headless.runtime.log"
set +e
"$FRAGPIPE_BIN" \
  --headless \
  --workflow "$WORKFLOW_MODIFIED" \
  --manifest "$MANIFEST_FILE" \
  --workdir "$RESULTS_DIR" \
  --config-tools-folder "$FRAGPIPE_TOOLS" 2>&1 | tee "$RUN_LOG"
FRAGPIPE_EXIT=${PIPESTATUS[0]}
set -e

if [ "$FRAGPIPE_EXIT" -ne 0 ]; then
  echo "FragPipe failed with exit code $FRAGPIPE_EXIT" >&2
  echo "===== Last 120 lines from fragpipe-headless.runtime.log =====" >&2
  tail -n 120 "$RUN_LOG" >&2 || true
  echo "===== End log tail =====" >&2
  exit "$FRAGPIPE_EXIT"
fi

# Rename output files with output_basename prefix
if [ -n "$OUTPUT_BASENAME" ]; then
  echo "=== Adding output_basename prefix: $OUTPUT_BASENAME ==="
  cd "$RESULTS_DIR"
  
  # List of files to rename (all files checked with if [ -f ] before renaming)
  for file in combined_protein.tsv combined_peptide.tsv combined_modified_peptide.tsv combined_ion.tsv \
              fragger.params fragpipe.workflow fragpipe-files.fp-manifest \
              experiment_annotation.tsv sdrf.tsv; do
    if [ -f "$file" ]; then
      new_name="${OUTPUT_BASENAME}_${file}"
      mv "$file" "$new_name"
      echo "Renamed: $file -> $new_name"
    fi
  done
  
  # Rename optional TMT-specific configuration file (only exists for TMT workflows)
  if [ -f "tmt-integrator-conf.yml" ]; then
    new_name="${OUTPUT_BASENAME}_tmt-integrator-conf.yml"
    mv "tmt-integrator-conf.yml" "$new_name"
    echo "Renamed: tmt-integrator-conf.yml -> $new_name"
  fi
  
  # Rename log file(s)
  for logfile in log*.txt; do
    if [ -f "$logfile" ]; then
      new_name="${OUTPUT_BASENAME}_${logfile}"
      mv "$logfile" "$new_name"
      echo "Renamed: $logfile -> $new_name"
    fi
  done
  
  # Rename tmt-report directory if it exists (only exists for TMT workflows)
  if [ -d "tmt-report" ]; then
    new_dir="${OUTPUT_BASENAME}_tmt-report"
    mv "tmt-report" "$new_dir"
    echo "Renamed: tmt-report -> $new_dir"
  fi
  
  cd - > /dev/null
fi

echo "=== FragPipe analysis complete ==="
