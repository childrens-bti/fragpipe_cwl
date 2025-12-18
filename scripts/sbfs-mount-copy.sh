#!/bin/bash
set -e
set -o pipefail

COHORT="$1"
RUN_SUBSET="$2"
DATA_DIR="/tmp/cavatica-data"
TMP_DIR="/tmp/mzml_files"

# Create directories
mkdir -p "$DATA_DIR" "$TMP_DIR"

# Set project and directory based on cohort
if [ "$COHORT" == "hope" ]; then
  echo "Processing HOPE cohort"
  PROJECT="harenzaj/hope-proteomics"
  CAVATICA_DIR="$DATA_DIR/projects/harenzaj/hope-proteomics/HOPE_TotalProteome_mzML"
  PATTERN="CPTAC_AYA_Proteome"
elif [ "$COHORT" == "cptac" ]; then
  echo "Processing CPTAC cohort"
  PROJECT="harenzaj/proteomics"
  CAVATICA_DIR="$DATA_DIR/projects/harenzaj/proteomics"
  PATTERN="CBTTC_PBT_Proteome"
else
  echo "Error: Invalid cohort. Use 'hope' or 'cptac'." >&2
  exit 1
fi

# Mount Cavatica project
echo "Mounting Cavatica project with SBFS..."
sbfs mount --profile default --project "$PROJECT" "$DATA_DIR"

# Wait for mount to become active
echo "Waiting for SBFS mount to become active..."
until mountpoint -q "$DATA_DIR"; do
  sleep 1
done
echo "Mount is active."

# Wait for proteomics files to become visible
echo "Waiting for proteomics files to become visible..."
until ls $CAVATICA_DIR/*Proteome* 1>/dev/null 2>&1; do
  sleep 1
done

# Copy mzML files
echo "Copying mzML files to temporary directory..."
if [ "$RUN_SUBSET" = "true" ]; then
  # Copy only first experiment (01C prefix)
  cp -R $CAVATICA_DIR/*01C${PATTERN}* "$TMP_DIR/" || true
else
  # Copy all experiments
  cp -R $CAVATICA_DIR/*${PATTERN}* "$TMP_DIR/" || true
fi

# Unzip mzML files
echo "Unzipping mzML files..."
find "$TMP_DIR" -name "*.mzML.gz" -exec gunzip -f {} \;

# Unmount
echo "Unmounting Cavatica project..."
sbfs unmount "$DATA_DIR"

# Create output manifest
echo "Creating mzML file list..."
find "$TMP_DIR" -name "*.mzML" > mzml_files.txt

echo "Done. Files ready in $TMP_DIR"
