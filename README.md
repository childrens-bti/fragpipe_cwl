# FragPipe CWL Workflows

This directory contains Common Workflow Language (CWL) implementations of the [FragPipe](https://github.com/Nesvilab/FragPipe) proteomics analysis pipeline developed by [Nesvilab](https://github.com/Nesvilab).

## Structure

```
fragpipe_cwl/
├── Dockerfile                         # Container with FragPipe and dependencies
├── fragpipe.cwl                      # Main workflow (supports .raw, .mzML.gz, and .mzML)
├── tools/                            # CWL CommandLineTool definitions
│   ├── detect-input-type.cwl         # Auto-detect input file type
│   ├── msconvert-raw.cwl             # Convert .raw to .mzML using msconvert
│   ├── philosopher-database.cwl      # Add decoys/contaminants to FASTA
│   ├── filter-canonical-peptides.cwl # Filter canonical peptides by gene symbols
│   ├── gunzip-mzml.cwl               # Decompress mzML files and generate manifest
│   ├── copy-mzml.cwl                 # Copy uncompressed mzML files
│   └── fragpipe-headless.cwl         # Main FragPipe execution
├── scripts/                          # Shell scripts called by CWL tools
│   ├── detect-input-type.sh          # Detect .raw, .mzML.gz, or .mzML files
│   ├── msconvert-raw.sh              # Raw file conversion with msconvert
│   ├── philosopher-database.sh       # Philosopher workspace and database prep
│   ├── filter-canonical-peptides.sh  # Gene symbol extraction and filtering
│   ├── gunzip-mzml.sh                # mzML decompression with TMT annotation support
│   ├── copy-mzml.sh                  # Copy mzML files with manifest generation
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

The primary workflow that processes proteomics data from mounted directories or direct file inputs. **Now supports .raw, .mzML.gz, and .mzML files with automatic detection.**

FragPipe supports a comprehensive set of workflow configurations available in the [FragPipe workflows repository](https://github.com/Nesvilab/FragPipe/tree/develop/workflows), including workflows for various quantitation methods (TMT, SILAC, LFQ, DIA, iTRAQ), post-translational modifications (phosphorylation, ubiquitination, acetylation, glycosylation), and specialized analyses (HLA peptidome, ABPP, open search).

**Steps:**
0. **Detect input type**: Auto-detect whether input files are .raw, .mzML.gz, or .mzML
1. **Convert/Process files** (conditionally based on detected type):
   - **Convert .raw to .mzML**: Use msconvert if input is .raw files
   - **Decompress .mzML.gz**: Gunzip if input is compressed mzML files
   - **Copy .mzML**: Direct copy if input is already uncompressed mzML
2. **Prepare database**: Add decoys and contaminants to custom FASTA using Philosopher
3. **Filter canonical peptides**: Remove canonical peptides by gene symbols
4. **Run FragPipe**: Execute FragPipe in headless mode with prepared database

**Key Features:**
- **Automatic input detection**: Detects .raw, .mzML.gz, or .mzML and processes accordingly
- **Raw file support**: Converts Thermo Fisher .raw files using msconvert
- **Automatic manifest generation**: Creates FragPipe manifest from processed files
- **TMT annotation file support**: Copies annotation.txt if present
- **Subset processing**: Process only specific experiments when `run_subset: true`
- **Writable mzML directory**: Uses InplaceUpdateRequirement for FragPipe temporary files
- **Dynamic FASTA path injection**: Workflow file updated at runtime with correct FASTA path
- **Backward compatible**: `skip_gunzip` parameter deprecated but maintained for compatibility

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

**For .mzML or .mzML.gz files:**
```bash
cwltool --leave-tmpdir --tmpdir-prefix ./.cwl-tmp/ --tmp-outdir-prefix ./.cwl-out/ \
    --outdir outputs/ fragpipe.cwl params/fragpipe-inputs.yml
```

**For .raw files:**
```bash
cwltool --leave-tmpdir --tmpdir-prefix ./.cwl-tmp/ --tmp-outdir-prefix ./.cwl-out/ \
    --outdir outputs/ fragpipe.cwl params/fragpipe-raw-inputs.yml
```

The workflow will automatically detect the input file type and process accordingly:
- **.raw files** → Convert using msconvert → Run FragPipe
- **.mzML.gz files** → Decompress → Run FragPipe  
- **.mzML files** → Copy → Run FragPipe

See [`params/fragpipe-inputs.yml`](params/fragpipe-inputs.yml) for mzML example and [`params/fragpipe-raw-inputs.yml`](params/fragpipe-raw-inputs.yml) for .raw file example.

### Cavatica Platform Execution

Upload workflow to Cavatica:
```bash
sbpack cavatica childrens-bti/impact-trial-cwl/fragpipe_cwl fragpipe-cavatica.cwl
```

Then configure and run via the Cavatica web interface.

## Key Features

| Feature | Description |
|---------|-------------|
| **Automatic Input Detection** | Detects .raw, .mzML.gz, or .mzML files and routes to appropriate converter |
| **Raw File Support** | Converts Thermo Fisher .raw files using msconvert from ProteoWizard |
| **Automatic Manifest Generation** | Creates FragPipe manifest from processed files, no manual manifest needed |
| **Subset Processing** | Process only first experiment (01C prefix) via `run_subset: true` |
| **TMT Annotation Support** | Automatically copies `annotation.txt` files from experiment directories |
| **Dynamic FASTA Injection** | Workflow file updated at runtime with correct FASTA path |
| **Writable mzML Directory** | Uses `InplaceUpdateRequirement` for FragPipe temporary files |
| **Hardcoded Binary Paths** | No PATH dependencies, uses absolute paths to Philosopher and FragPipe |
| **SBFS Mount Support** | Direct mounting of Cavatica projects for local execution |
| **Backward Compatible** | Maintains `skip_gunzip` parameter for existing workflows |

## Docker Image

**Image:** `pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest`

**Contents:**
- FragPipe 22.0 at `/fragpipe_bin/fragPipe-22.0/fragpipe/`
- Philosopher v5.1.1 at `/fragpipe_bin/fragPipe-22.0/fragpipe/tools/Philosopher/philosopher-v5.1.1`
- MSFragger and other FragPipe tools
- Shell scripts at `/opt/impact_trial/scripts/`

**For .raw file conversion**, you also need:
- **MSConvert Docker Image**: `chambm/pwiz-skyline-i-agree-to-the-vendor-licenses`
  - Contains ProteoWizard msconvert tool
  - Includes wine for running Windows-based msconvert
  - Used only for the `msconvert-raw.cwl` step

**Building:**
```bash
docker build -t pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest .
docker push pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest
```

## Tool Descriptions

### detect-input-type.cwl
Automatically detects input file type by examining the source directory for .raw, .mzML.gz, or .mzML files.

**Outputs:**
- `input_type`: String value of "raw", "mzml_gz", or "mzml"

### msconvert-raw.cwl
Converts Thermo Fisher .raw files to mzML format using msconvert from ProteoWizard.

**Requirements:**
- Docker image: `chambm/pwiz-skyline-i-agree-to-the-vendor-licenses`
- Uses wine to run Windows-based msconvert tool

**Conversion Parameters:**
- `--64`: Use 64-bit precision
- `--zlib`: Compress output
- `--filter "peakPicking"`: Centroid data if not already
- `--filter "zeroSamples removeExtra 1-"`: Remove zero samples

**Outputs:**
- `mzml_directory`: Directory containing converted mzML files
- `mzml_manifest`: FragPipe manifest file (`.fp-manifest` format)

**Note:** Based on [Nesvilab/msconvert-scripts](https://github.com/Nesvilab/msconvert-scripts)

### gunzip-mzml.cwl
Decompresses gzipped mzML files from a mounted directory and generates a FragPipe-compatible manifest file. Supports subset processing (files in `/01C*/` directories only) and automatically copies TMT annotation files.

**Outputs:**
- `mzml_directory`: Directory containing decompressed mzML files
- `mzml_file_list`: Simple text list of mzML file paths
- `mzml_manifest`: FragPipe manifest file (`.fp-manifest` format)

### copy-mzml.cwl
Copies already uncompressed mzML files and generates a FragPipe manifest.

**Outputs:**
- `mzml_directory`: Directory containing copied mzML files
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
  - Main FragPipe image: `pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest`
  - MSConvert image (for .raw files): `chambm/pwiz-skyline-i-agree-to-the-vendor-licenses` (auto-pulled)
- **SBFS**: Seven Bridges File System (for local workflow with Cavatica mounts)
  - Requires `/etc/fuse.conf` with `user_allow_other` enabled
  - Requires Cavatica credentials configured
- **Cavatica Account**: For accessing project data and platform execution

**Note on .raw file conversion:**
- When processing .raw files, cwltool will automatically pull the `chambm/pwiz-skyline-i-agree-to-the-vendor-licenses` Docker image
- This image is ~4GB and contains ProteoWizard msconvert with wine
- First-time conversion will take longer due to image download
- By using this image, you agree to vendor licenses for Thermo Fisher raw file reading libraries

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

## Credits

This CWL workflow implementation is based on the [FragPipe](https://github.com/Nesvilab/FragPipe) pipeline developed by [Nesvilab](https://github.com/Nesvilab). FragPipe provides an integrated environment for MS/MS proteomics data analysis and includes the following components:

- **MSFragger**: Fast peptide MS/MS database search engine
- **Philosopher**: Downstream proteomics data validation and analysis
- **IonQuant**: Peptide quantification tool
- **diaTracer**: DIA data processing

For more information about FragPipe workflows and available analysis configurations, see the [workflows directory](https://github.com/Nesvilab/FragPipe/tree/develop/workflows) in the FragPipe repository.

## Notes

- The Docker image includes FragPipe 22.0 with all required tools
- JAR files (MSFragger, IonQuant, diaTracer) must be copied during Docker build
- Resource requirements are specified as hints for Cavatica platform optimization
