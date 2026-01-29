# FragPipe CWL Workflows

This directory contains Common Workflow Language (CWL) implementations of the FragPipe proteomics analysis pipeline.

## Structure

```
fragpipe_cwl/
├── Dockerfile                         # Container with FragPipe and dependencies
├── fragpipe.cwl                      # Main workflow (supports both local and Cavatica)
├── tools/                            # CWL CommandLineTool definitions
│   ├── philosopher-database.cwl      # Add decoys/contaminants to FASTA
│   ├── filter-canonical-peptides.cwl # Filter canonical peptides by gene symbols
│   ├── gunzip-mzml.cwl               # Decompress mzML files and generate manifest
│   └── fragpipe-headless.cwl         # Main FragPipe execution
├── scripts/                          # Shell scripts called by CWL tools
│   ├── philosopher-database.sh       # Philosopher workspace and database prep
│   ├── filter-canonical-peptides.sh  # Gene symbol extraction and filtering
│   ├── gunzip-mzml.sh                # mzML decompression with TMT annotation support
│   ├── fragpipe-headless.sh          # FragPipe headless execution
│   └── sbfs-mount.sh                 # SBFS mount utility (standalone)
├── params/                           # Input parameter files
│   └── fragpipe-inputs.yml           # Example input parameters
└── data/                             # Input data and references
    ├── custom_filtered.fasta         # Custom query FASTA
    ├── references/                   # Reference databases
    └── cavatica-data/                # SBFS mount point
```

## Workflows

### Main Workflow (`fragpipe.cwl`)

The primary workflow that processes proteomics data from mounted directories or direct file inputs.

**Steps:**
1. **Gunzip mzML files**: Decompress mzML.gz files from mounted directory and generate FragPipe manifest
2. **Prepare database**: Add decoys and contaminants to custom FASTA using Philosopher
3. **Filter canonical peptides**: Remove canonical peptides by gene symbols
4. **Run FragPipe**: Execute FragPipe in headless mode with prepared database

**Key Features:**
- Automatic manifest generation from decompressed files
- TMT annotation file support (copies annotation.txt if present)
- Subset processing (process only 01C experiments when `run_subset: true`)
- Writable mzML directory for FragPipe temporary files (InplaceUpdateRequirement)
- Dynamic FASTA path injection into workflow file

## Usage

### Prerequisites

1. **Mount Cavatica project** (for local execution):
```bash
# Check if already mounted
mountpoint -q data/cavatica-data

# Mount if needed
bash scripts/sbfs-mount.sh harenzaj/proteomics data/cavatica-data
```

2. **Validate workflow**:
```bash
cwltool --validate fragpipe.cwl
```

### Local Execution

```bash
cwltool --leave-tmpdir --tmpdir-prefix ./.cwl-tmp/ --tmp-outdir-prefix ./.cwl-out/ \
    --outdir outputs/ fragpipe.cwl params/fragpipe-inputs.yml
```

See [`params/fragpipe-inputs.yml`](params/fragpipe-inputs.yml) for an example input parameter file.

### Cavatica Platform Execution

Upload workflow to Cavatica:
```bash
sbpack cavatica childrens-bti/impact-trial-cwl/fragpipe_cwl fragpipe-cavatica.cwl
```

Then configure and run via the Cavatica web interface.

## Key Features

| Feature | Description |
|---------|-------------|
| **Automatic Manifest Generation** | Creates FragPipe manifest from decompressed files, no manual manifest needed |
| **Subset Processing** | Process only first experiment (01C) for testing via `run_subset: true` |
| **TMT Annotation Support** | Automatically copies `annotation.txt` files from experiment directories |
| **Dynamic FASTA Injection** | Workflow file updated at runtime with correct FASTA path |
| **Writable mzML Directory** | Uses `InplaceUpdateRequirement` for FragPipe temporary files |
| **Hardcoded Binary Paths** | No PATH dependencies, uses absolute paths to Philosopher and FragPipe |
| **SBFS Mount Support** | Direct mounting of Cavatica projects for local execution |

## Docker Image

**Image:** `pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest`

**Contents:**
- FragPipe 22.0 at `/fragpipe_bin/fragPipe-22.0/fragpipe/`
- Philosopher v5.1.1 at `/fragpipe_bin/fragPipe-22.0/fragpipe/tools/Philosopher/philosopher-v5.1.1`
- MSFragger and other FragPipe tools
- Shell scripts at `/opt/impact_trial/scripts/`

**Building:**
```bash
docker build -t pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest .
docker push pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest
```

## Tool Descriptions

### gunzip-mzml.cwl
Decompresses gzipped mzML files from a mounted directory and generates a FragPipe-compatible manifest file. Supports subset processing (files in `/01C*/` directories only) and automatically copies TMT annotation files.

**Outputs:**
- `mzml_directory`: Directory containing decompressed mzML files
- `mzml_file_list`: Simple text list of mzML file paths
- `mzml_manifest`: FragPipe manifest file (`.fp-manifest` format)

### philosopher-database.cwl
Initializes a Philosopher workspace and adds decoys/contaminants from UniProt canonical database to the custom FASTA file.

**Key Features:**
- Uses hardcoded Philosopher binary path in container
- Adds reversed decoys with `rev_` tag
- Includes contaminant proteins

### filter-canonical-peptides.cwl
Extracts gene symbols from the custom FASTA and filters out canonical peptides annotated to those genes from the combined database.

**Gene Sources:**
- Splice event genes
- SNV genes  
- Arriba fusion genes
- STAR fusion genes

### fragpipe-headless.cwl
Runs FragPipe in headless mode with specified workflow, manifest, and processed FASTA database.

**Key Features:**
- `InplaceUpdateRequirement` for writable mzML directory
- Dynamic FASTA path injection via `sed` modification of workflow file
- Writable HOME directory for FragPipe config/cache
- Copies FragPipe installation to writable runtime directory

## Requirements

- **CWL Runner**: cwltool 3.1+ (for CWL v1.2 support including `InplaceUpdateRequirement`)
- **Docker**: For containerized execution
- **SBFS**: Seven Bridges File System (for local workflow with Cavatica mounts)
  - Requires `/etc/fuse.conf` with `user_allow_other` enabled
  - Requires Cavatica credentials configured
- **Cavatica Account**: For accessing project data and platform execution

## Troubleshooting

### SBFS Mount Issues
```bash
# Check if mount is active
mountpoint -q data/cavatica-data

# Unmount if needed
sbfs unmount data/cavatica-data

# Remount
bash scripts/sbfs-mount.sh harenzaj/proteomics data/cavatica-data
```

### FUSE Permission Errors
Ensure `/etc/fuse.conf` contains:
```
user_allow_other
```

### FragPipe HOME Directory Errors
The workflow automatically sets `HOME` to a writable location. If you see errors about `/home/rstudio/.config/FragPipe`, ensure:
- `EnvVarRequirement` is properly set in `fragpipe-headless.cwl`
- Docker container has write access to the working directory

### Manifest File Errors
The workflow generates the manifest automatically. The input `manifest_file` parameter is kept for backward compatibility but is not used - the generated manifest from `gunzip-mzml` step is used instead.

## Output Files

FragPipe results are written to the specified output directory with the following structure:
```
outputs/
├── results_directory/          # Complete FragPipe output
├── combined_protein.tsv        # Protein quantification (if available)
├── combined_peptide.tsv        # Peptide quantification (if available)
└── combined_ion.tsv            # Ion quantification (if available)
```

## Notes

- The Docker image includes FragPipe 22.0 with all required tools
- JAR files (MSFragger, IonQuant, diaTracer) must be copied during Docker build
- Resource requirements are specified as hints for Cavatica platform optimization
