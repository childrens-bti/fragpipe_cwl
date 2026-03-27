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
RESULTS_DIR="results"
RESULTS_DIR="$(cd "$(pwd)" && echo "$(pwd)/$RESULTS_DIR")"
mkdir -p "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR/diann-output"

# Get absolute path to FASTA for FragPipe
FASTA_ABS="$(cd "$(dirname "$FILTERED_FASTA")" && pwd)/$(basename "$FILTERED_FASTA")"

# Create modified workflow file with correct FASTA path
WORKFLOW_MODIFIED="$(pwd)/workflow_modified.workflow"
awk -v db="database.db-path=$FASTA_ABS" 'BEGIN{done=0} /^database\.db-path=/{if(!done){print db; done=1}; next} {print} END{if(!done) print db}' "$WORKFLOW_FILE" > "$WORKFLOW_MODIFIED"

# Run FragPipe and preserve exit status so we can still prefix any generated outputs.
set +e
"$FRAGPIPE_BIN" \
  --headless \
  --workflow "$WORKFLOW_MODIFIED" \
  --manifest "$MANIFEST_FILE" \
  --workdir "$RESULTS_DIR" \
  --config-tools-folder "$FRAGPIPE_TOOLS"
fragpipe_exit=$?
set -e

# Rename output files with output_basename prefix
if [ -n "$OUTPUT_BASENAME" ]; then
  echo "=== Adding output_basename prefix: $OUTPUT_BASENAME ==="
  cd "$RESULTS_DIR"

  # Common metadata/config outputs
  for file in fragger.params fragpipe.workflow fragpipe-files.fp-manifest \
              experiment_annotation.tsv sdrf.tsv; do
    if [ -f "$file" ]; then
      new_name="${OUTPUT_BASENAME}_${file}"
      mv "$file" "$new_name"
      echo "Renamed: $file -> $new_name"
    fi
  done

  # DIA/Philosopher tables that are commonly present in DIA workflows
  for file in psm.tsv peptide.tsv protein.tsv ion.tsv protein.fas library.tsv \
              combined.prot.xml spectraRT.tsv spectraRT_full.tsv spectraRT.predicted.bin \
              msbooster_params.txt filter.log filelist_easypqp_library.txt \
              filelist_speclibgen.txt filelist_proteinprophet.txt easypqp_rt_reference_run.tsv; do
    if [ -f "$file" ]; then
      new_name="${OUTPUT_BASENAME}_${file}"
      mv "$file" "$new_name"
      echo "Renamed: $file -> $new_name"
    fi
  done

  # Keep per-sample artifacts stable (pepXML/pin/interact/percolator) to avoid very long names.

  # Rename optional TMT-specific configuration file
  if [ -f "tmt-integrator-conf.yml" ]; then
    new_name="${OUTPUT_BASENAME}_tmt-integrator-conf.yml"
    mv "tmt-integrator-conf.yml" "$new_name"
    echo "Renamed: tmt-integrator-conf.yml -> $new_name"
  fi

  # Rename FragPipe log file(s)
  for logfile in log*.txt; do
    if [ -f "$logfile" ]; then
      new_name="${OUTPUT_BASENAME}_${logfile}"
      mv "$logfile" "$new_name"
      echo "Renamed: $logfile -> $new_name"
    fi
  done

  # Rename optional directories
  for dir in tmt-report MSBooster_plots easypqp_files; do
    if [ -d "$dir" ]; then
      new_dir="${OUTPUT_BASENAME}_${dir}"
      mv "$dir" "$new_dir"
      echo "Renamed: $dir -> $new_dir"
    fi
  done

  # Keep results/diann-output as a stable directory, but prefix key DIA-NN files inside it.
  if [ -d "diann-output" ]; then
    cd "diann-output"
    for file in report.tsv report2.tsv report.pr_matrix.tsv report.pg_matrix.tsv \
                report.gg_matrix.tsv report.stats.tsv MSstats.csv; do
      if [ -f "$file" ]; then
        new_name="${OUTPUT_BASENAME}_${file}"
        mv "$file" "$new_name"
        echo "Renamed: diann-output/$file -> diann-output/$new_name"
      fi
    done
    cd ..
  fi

  cd - > /dev/null
fi

if [ "$fragpipe_exit" -ne 0 ]; then
  echo "=== FragPipe analysis failed with exit code: $fragpipe_exit ==="
  exit "$fragpipe_exit"
fi

echo "=== FragPipe DIA analysis complete ==="
