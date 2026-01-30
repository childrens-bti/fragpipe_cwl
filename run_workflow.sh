#!/usr/bin/env bash
set -e

# Wrapper script for running FragPipe CWL workflow with automatic permission fix
# Usage: ./run_workflow.sh <workflow.cwl> <inputs.yml> <output_dir>

WORKFLOW="${1:-fragpipe.cwl}"
INPUTS="${2:-params/fragpipe-impact-test-inputs.yml}"
OUTDIR="${3:-outputs/impact-trial-test-N849}"

echo "Running CWL workflow..."
echo "  Workflow: $WORKFLOW"
echo "  Inputs:   $INPUTS"
echo "  Output:   $OUTDIR"
echo ""

# Run cwltool with --no-match-user (required for wine/msconvert)
cwltool --no-match-user \
  --leave-tmpdir \
  --tmpdir-prefix ./.cwl-tmp/ \
  --tmp-outdir-prefix ./.cwl-out/ \
  --outdir "$OUTDIR" \
  "$WORKFLOW" "$INPUTS" 2>&1 | tee "logs/$(basename $OUTDIR).log"

# Capture cwltool exit code
CWLTOOL_EXIT=$?

# Fix permissions on temporary output
echo ""
echo "Fixing file permissions..."
sudo chown -R $USER:$USER .cwl-out/ 2>/dev/null || true

# Manually copy results to output directory if cwltool couldn't due to permissions
if [ $CWLTOOL_EXIT -eq 1 ]; then
  echo "Copying results to output directory..."
  
  # Find the most recent results directory
  LATEST_RESULTS=$(find .cwl-out/ -type d -name "results" | head -1)
  
  if [ -n "$LATEST_RESULTS" ]; then
    mkdir -p "$OUTDIR"
    cp -r "$LATEST_RESULTS"/* "$OUTDIR/" 2>/dev/null || true
    
    # Check if copy was successful
    if [ -f "$OUTDIR/combined_ion.tsv" ]; then
      echo "✓ Results copied successfully to $OUTDIR"
      CWLTOOL_EXIT=0
    else
      echo "✗ Failed to copy results"
    fi
  else
    echo "✗ Could not find results directory"
  fi
fi

# Fix permissions on final output
sudo chown -R $USER:$USER "$OUTDIR" 2>/dev/null || true

if [ $CWLTOOL_EXIT -eq 0 ]; then
  echo ""
  echo "✓ Workflow completed successfully!"
  echo "  Output directory: $OUTDIR"
  exit 0
else
  echo ""
  echo "✗ Workflow failed with exit code $CWLTOOL_EXIT"
  exit $CWLTOOL_EXIT
fi
