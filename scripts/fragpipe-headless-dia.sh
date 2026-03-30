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
# set +e remains active through the workaround block so we can safely inspect/handle
# non-zero exits without triggering set -e early termination.
set +e
"$FRAGPIPE_BIN" \
  --headless \
  --workflow "$WORKFLOW_MODIFIED" \
  --manifest "$MANIFEST_FILE" \
  --workdir "$RESULTS_DIR" \
  --config-tools-folder "$FRAGPIPE_TOOLS"
fragpipe_exit=$?

# --- Bug workaround: FragPipe issue #2050 ---
# DIA-NN writes report2.tsv but the Propagation step hard-codes report.tsv.
# If FragPipe failed with report2.tsv present but report.tsv absent, copy the file
# and re-run Propagation + MSstats directly (set +e is still in effect here so we
# can capture each exit code without the script aborting on us).
if [ "$fragpipe_exit" -ne 0 ] && \
   [ -f "$RESULTS_DIR/diann-output/report2.tsv" ] && \
   [ ! -f "$RESULTS_DIR/diann-output/report.tsv" ]; then

  echo "=== Applying FragPipe #2050 workaround: copying report2.tsv -> report.tsv ==="
  cp "$RESULTS_DIR/diann-output/report2.tsv" "$RESULTS_DIR/diann-output/report.tsv"

  # Locate JAR files from the runtime directory
  BATMASS_JAR=$(ls "$RUNTIME_DIR/tools/batmass-io"*.jar 2>/dev/null | head -1)
  COMMONS_JAR=$(ls "$RUNTIME_DIR/lib/commons-io"*.jar 2>/dev/null | head -1)
  FRAGPIPE_JAR=$(ls "$RUNTIME_DIR/lib/fragpipe"*.jar 2>/dev/null | head -1)

  echo "=== Re-running DIA-NN: Propagate information ==="
  cd "$RESULTS_DIR/diann-output"
  java -Duser.home="$HOME" \
       -cp "${BATMASS_JAR}:${FRAGPIPE_JAR}:${FRAGPIPE_JAR}" \
       com.dmtavt.fragpipe.tools.diann.Propagation "$RESULTS_DIR"
  prop_exit=$?
  cd "$RESULTS_DIR"

  if [ "$prop_exit" -eq 0 ]; then
    echo "=== Re-running DIA-NN: Convert to MSstats.csv ==="
    DIANN_Q=$(grep "^diann.q-value=" "$RESULTS_DIR/fragpipe.workflow" 2>/dev/null | cut -d= -f2)
    DIANN_Q=${DIANN_Q:-0.01}
    cd "$RESULTS_DIR/diann-output"
    java -Duser.home="$HOME" \
         -cp "${COMMONS_JAR}:${FRAGPIPE_JAR}:${FRAGPIPE_JAR}" \
         com.dmtavt.fragpipe.tools.diann.DiannToMsstats \
         report.tsv ./ "$RESULTS_DIR/psm.tsv" "$DIANN_Q" 1 "$DIANN_Q" "$DIANN_Q" \
         "$RESULTS_DIR/fragpipe-files.fp-manifest"
    msstats_exit=$?
    cd "$RESULTS_DIR"
    [ "$msstats_exit" -eq 0 ] && fragpipe_exit=0
  fi
fi

set -e

# Rename output files with output_basename prefix
if [ -n "$OUTPUT_BASENAME" ]; then
  echo "=== Adding output_basename prefix: $OUTPUT_BASENAME ==="
  cd "$RESULTS_DIR"

  # DIA workflows may output fragger_dia.params instead of fragger.params.
  # Normalize to fragger.params so CWL output globs stay consistent across modes.
  if [ -f "fragger_dia.params" ] && [ ! -f "fragger.params" ]; then
    mv "fragger_dia.params" "fragger.params"
    echo "Renamed: fragger_dia.params -> fragger.params"
  fi

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
