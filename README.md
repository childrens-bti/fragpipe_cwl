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
│   ├── filter-control-peptides.cwl   # Optional control-overlap peptide filtering
│   ├── gunzip-mzml.cwl               # Decompress mzML files and generate manifest
│   ├── copy-mzml.cwl                 # Copy uncompressed mzML files
│   └── fragpipe-headless.cwl         # Main FragPipe execution
├── scripts/                          # Shell scripts called by CWL tools
│   ├── detect-input-type.sh          # Detect .raw, .mzML.gz, or .mzML files
│   ├── msconvert-raw.sh              # Raw file conversion with msconvert
│   ├── philosopher-database.sh       # Philosopher workspace and database prep
│   ├── filter-canonical-peptides.sh  # Gene symbol extraction and filtering
│   ├── filter-control-peptides.py    # Control-overlap peptide filtering logic
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
5. **Optional control-overlap filtering**: Keep non-canonical, non-decoy peptides and remove overlap with control peptides (exact match or containment)

See [Key Features](#key-features) section below for complete feature list.

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

### Workflow Execution

The workflow automatically detects your input file type (.raw, .mzML.gz, or .mzML) and processes accordingly. Follow these steps:

#### Step 1: Prepare Your Data

Organize your files in a source directory with experiment subfolders:

**For .mzML or .mzML.gz files:**
```
source_dir/
├── experiment_1/
│   ├── sample_001.mzML      (or .mzML.gz)
│   ├── sample_002.mzML
│   └── annotation.txt        (optional, for TMT workflows)
├── experiment_2/
│   ├── sample_003.mzML
│   └── sample_004.mzML
```

**For .raw files:**
```
source_dir/
├── experiment_1/
│   ├── sample_001.raw
│   ├── sample_002.raw
│   └── annotation.txt        (optional, for TMT workflows)
├── experiment_2/
│   ├── sample_003.raw
│   └── sample_004.raw
```

#### Step 2: Create a Manifest File

Create a manifest file (`.fp-manifest`) listing the files to process. See [Input Manifest Examples](#input-manifest-examples) section for detailed examples and format requirements.

Brief format:
```
dummy	sample_001		DDA
dummy	sample_002		DDA
```

Column 2 must match your filenames (without extensions). Column 1 is not used by the workflow.

#### Step 3: Prepare Input Parameters

Create a parameters YAML file. Choose one based on your file type:

#### Understanding `custom_filtered.fasta` Input IDs

The `query_fasta` input (commonly `data/custom_filtered.fasta`) contains tumor-specific peptide/protein entries translated from multiple variant sources. Header IDs encode source type and metadata.

Common header types and examples:

- **SNV/Indel-derived IDs** (multiple subtypes in one file)
  - `missense_mutation|BS_1CZPVCXR:BS_YVRSCEC6|CHD5|ENSG00000116254|ENST00000262450|ENSP00000262450|c.4601C>A|p.P1534H|peptMutPos=1534`
  - `nonsense_mutation|BS_1CZPVCXR:BS_YVRSCEC6|EPHA6|ENSG00000080224|ENST00000389672|ENSP00000374323|c.1918G>T|p.G640*|peptMutPos=640`
  - `frame_shift_del|BS_1CZPVCXR:BS_YVRSCEC6|ZSWIM5|ENSG00000162415|ENST00000359600|ENSP00000352614|c.481del|p.S161Pfs*42|peptMutPos=161`
  - `frame_shift_ins|BS_1CZPVCXR:BS_YVRSCEC6|ZNF534|ENSG00000198633|ENST00000433050|ENSP00000391358|c.1030_1031insGG|p.H344Rfs*88|peptMutPos=344`
  - `in_frame_del|BS_1CZPVCXR:BS_YVRSCEC6|UBC|ENSG00000150991|ENST00000339647|ENSP00000344818|c.609_611del|p.E203del|peptMutPos=203`

- **STAR-fusion IDs**
  - `star_fusion|MFSD14B--RTF2|MFSD14B^ENSG00000148110.17|chr9:94446936:+|RTF2^ENSG00000022277.13|chr20:56513315:+|leftCDS_id:ENST00000375344.8|1-843|rightCDS_id:ENST00000357348.10|478-921|INFRAME|Protein_fusion_site:281`

- **Arriba-fusion IDs**
  - `arriba_fusion|PTCH1--FANCC|PTCH1|chr9:95453478|ENST00000437951.6|FANCC|chr9:95411677|.|out-of-frame|Protein_fusion_site:65`

- **Splice-event IDs**
  - `chr17:76467717-76467727_76468671-76468909_AANAT_phase0`

Field notes:

- `ENSG...` = gene ID, `ENST...` = transcript ID, `ENSP...` = protein ID
- `c.` fields are coding-DNA changes (HGVS-like), `p.` fields are protein changes
- `peptMutPos=<N>` marks mutation position used in peptide/protein context
- `Protein_fusion_site:<N>` is the amino-acid fusion junction position
- `phase0/1/2` indicates translation frame for splice-junction-derived entries

**For .mzML files (params/myworkflow-inputs.yml):**
```yaml
query_fasta:
  class: File
  path: $(pwd)/data/custom_filtered.fasta

uniprot_canonical_fasta:
  class: File
  path: $(pwd)/data/references/UP000005640_9606.fasta.gz

workflow_file:
  class: File
  path: $(pwd)/data/HOPEproteome_TMT11workflow.workflow

manifest_file:
  class: File
  path: $(pwd)/manifest.fp-manifest

mzml_source_dir:
  class: Directory
  path: /path/to/source_dir

input_type: "mzml"

output_basename: "SAMPLE001"

# Optional: control-run peptide table for overlap filtering
control_combined_peptide:
  class: File
  path: $(pwd)/data/control_combined_peptide.tsv

run_subset: false
subset_pattern: ""
```

**For .raw files:**
```yaml
query_fasta:
  class: File
  path: $(pwd)/data/custom_filtered.fasta

uniprot_canonical_fasta:
  class: File
  path: $(pwd)/data/references/UP000005640_9606.fasta.gz

workflow_file:
  class: File
  path: $(pwd)/data/HOPEproteome_TMT11workflow.workflow

manifest_file:
  class: File
  path: $(pwd)/manifest.fp-manifest

mzml_source_dir:
  class: Directory
  path: /path/to/source_dir       # Directory with .raw files

input_type: "raw"

output_basename: "SAMPLE001"

run_subset: false
subset_pattern: ""
```

**For .mzML.gz files:**
```yaml
input_type: "mzml_gz"  # Change only this parameter
# ... rest same as .mzML example
```

#### Step 4: Run Workflow

Execute the workflow with your chosen parameters file. See [Complete Examples](#complete-examples) section below for specific commands.

#### Step 5: Check Results

After successful execution, outputs appear in the `outputs/` directory. See [Output Files](#output-files) section for detailed descriptions of each output file.

### Complete Examples

**Example 1: Process mzML files from HOPE study**
```bash
cwltool --leave-tmpdir --tmpdir-prefix ./.cwl-tmp/ \
    --tmp-outdir-prefix ./.cwl-out/ \
    --outdir outputs/ \
    fragpipe.cwl params/fragpipe-hope-inputs.yml
```

**Example 2: Process raw files (auto-converted)**
```bash
cwltool --leave-tmpdir --tmpdir-prefix ./.cwl-tmp/ \
    --tmp-outdir-prefix ./.cwl-out/ \
    --outdir outputs/ \
    fragpipe.cwl params/fragpipe-raw-inputs.yml
```

**Example 3: Process subset (N849 patient)**
```bash
# Edit params file to set:
# - run_subset: true
# - subset_pattern: "N849"
# - output_basename: "HOPE_N849"

cwltool --leave-tmpdir --tmpdir-prefix ./.cwl-tmp/ \
    --tmp-outdir-prefix ./.cwl-out/ \
    --outdir outputs/ \
    fragpipe.cwl params/fragpipe-hope-inputs-N849.yml
```

### Cavatica Platform Execution

Upload workflow to Cavatica:
```bash
sbpack cavatica childrens-bti/impact-trial-cwl/fragpipe_cwl fragpipe-cavatica.cwl
```

Then configure and run via the Cavatica web interface.

For parameter file examples, see [`params/fragpipe-inputs.yml`](params/fragpipe-inputs.yml) for mzML and [`params/fragpipe-raw-inputs.yml`](params/fragpipe-raw-inputs.yml) for .raw files.

## Manifest File Specification

### Overview

The manifest file (`.fp-manifest`) is a tab-separated file that lists the mzML/raw files to be processed. The workflow handles manifest files differently depending on the stage:
- **Input manifest**: Used only to identify which files to process
- **Generated manifest**: Created automatically with correct file paths for FragPipe execution

### File Format

The manifest file has **4 tab-separated columns**:

```
<file_path>	<basename>	<annotation>	<data_type>
```

| Column | Name | Purpose | Example |
|--------|------|---------|---------|
| 1 | File Path | Deprecated/ignored by workflow (for reference only) | `/home/data/exp1/file1.mzML` |
| 2 | Basename | **REQUIRED** - Used to find matching files in source directory | `file1` |
| 3 | Annotation | Optional - Empty or annotation label | `` |
| 4 | Data Type | Acquisition type: DDA, DIA, or PRM | `DDA` |

### Important Notes

1. **Column 1 is not used** - The workflow reads basenames from column 2 to locate files
2. **Column 2 must match filenames exactly** (without extension)
3. **Manifest is auto-regenerated** - A new manifest with correct full paths is created before FragPipe execution

### Input Manifest Examples

#### Basic Example (mzML or raw files)

If your source directory contains:
```
source_dir/
├── experiment_A/
│   ├── sample_001.mzML  (or .raw or .mzML.gz)
│   ├── sample_002.mzML
├── experiment_B/
│   ├── sample_003.mzML
```

Your manifest should be:
```
dummy	sample_001		DDA
dummy	sample_002		DDA
dummy	sample_003		DDA
```

#### Subset Processing Example

To process only files in the `N849/` folder with `run_subset: true` and `subset_pattern: "N849"`:

```
source_dir/
├── experiment_1/        ← Skipped
│   └── file_1.mzML
├── N849/                ← Processed
│   ├── file_2.mzML
│   └── file_3.mzML
```

Use the same manifest format; the workflow filters files based on the pattern.

### Manifest Processing Flow

```
Input manifest (column 2)
    ↓ Extract basenames
Find matching files in source directory
    ↓ Based on subset_pattern if enabled
Copy/Convert to working directory
    ↓
Auto-generate new manifest with full local paths
    ↓ Pass to FragPipe
```

## Key Features

| Feature | Description |
|---------|-------------|
| **Automatic Input Detection** | Detects .raw, .mzML.gz, or .mzML files and routes to appropriate converter |
| **Raw File Support** | Converts Thermo Fisher .raw files using msconvert from ProteoWizard |
| **Automatic Manifest Generation** | Creates FragPipe manifest from processed files, no manual manifest needed |
| **Subset Processing** | Process only first experiment (subfolder name) via `run_subset: true` |
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

## Output Files

FragPipe results are written to the specified output directory with the following structure:

```
outputs/
├── SAMPLE001_combined_protein.tsv              # Protein quantification results
├── SAMPLE001_combined_peptide.tsv              # Peptide quantification results
├── SAMPLE001_combined_peptide_control_filtered.tsv # Tumor-specific peptides after control overlap filtering (optional)
├── SAMPLE001_input_tumor_specific_peptides.tsv     # Input tumor-specific peptide rows (non-canonical, non-decoy; optional)
├── SAMPLE001_control_tumor_specific_peptides.tsv   # Control tumor-specific peptide rows (non-canonical, non-decoy; optional)
├── SAMPLE001_control_overlap_summary.txt           # Control-overlap filtering summary (optional)
├── SAMPLE001_combined_modified_peptide.tsv     # Modified peptide quantification
├── SAMPLE001_combined_ion.tsv                  # Ion-level quantification
├── SAMPLE001_fragger.params                    # MSFragger parameter file used
├── SAMPLE001_fragpipe.workflow                 # Workflow configuration used
├── SAMPLE001_fragpipe-files.fp-manifest        # Generated manifest (with full paths)
├── SAMPLE001_experiment_annotation.tsv         # Experiment metadata
├── SAMPLE001_sdrf.tsv                          # SDRF format metadata
├── SAMPLE001_tmt-integrator-conf.yml           # TMT configuration (if applicable)
├── SAMPLE001_tmt-report/                       # TMT quantification results (if applicable)
└── SAMPLE001_log*.txt                          # Execution log
```

## Credits

This CWL workflow implementation is based on the [FragPipe](https://github.com/Nesvilab/FragPipe) pipeline developed by [Nesvilab](https://github.com/Nesvilab). FragPipe provides an integrated environment for MS/MS proteomics data analysis and includes the following components:

- **MSFragger**: Fast peptide MS/MS database search engine
- **Philosopher**: Downstream proteomics data validation and analysis
- **IonQuant**: Peptide quantification tool
- **diaTracer**: DIA data processing

For more information about FragPipe workflows and available analysis configurations, see the [workflows directory](https://github.com/Nesvilab/FragPipe/tree/develop/workflows) in the FragPipe repository.

