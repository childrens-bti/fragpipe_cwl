# FragPipe CWL Workflows

This directory contains Common Workflow Language (CWL) implementations of the [FragPipe](https://github.com/Nesvilab/FragPipe) proteomics analysis pipeline developed by [Nesvilab](https://github.com/Nesvilab).

## Structure

```
fragpipe_cwl/
├── Dockerfile                         # Container with FragPipe and dependencies
├── fragpipe.cwl                      # Main workflow (supports .raw, .mzML.gz, .mzML, and Bruker .d)
├── tools/                            # CWL CommandLineTool definitions
│   ├── msconvert-raw.cwl             # Convert .raw to .mzML using msconvert
│   ├── philosopher-database.cwl      # Add decoys/contaminants to FASTA
│   ├── filter-canonical-peptides.cwl # Filter canonical peptides by gene symbols
│   ├── filter-control-peptides.cwl   # Optional control-overlap peptide filtering
│   ├── gunzip-mzml.cwl               # Decompress mzML files and generate manifest
│   ├── copy-mzml.cwl                 # Copy uncompressed mzML files
│   ├── extract-d.cwl                 # Extract Bruker timsTOF .d runs from archives
│   ├── fragpipe-headless.cwl         # Main FragPipe execution
│   └── fragpipe-pdv.cwl              # Optional PDV batch plotting
├── scripts/                          # Shell scripts called by CWL tools
│   ├── msconvert-raw.sh              # Raw file conversion with msconvert
│   ├── philosopher-database.sh       # Philosopher workspace and database prep
│   ├── filter-canonical-peptides.sh  # Gene symbol extraction and filtering
│   ├── filter-control-peptides.py    # Control-overlap peptide filtering logic
│   ├── gunzip-mzml.sh                # mzML decompression with TMT annotation support
│   ├── copy-mzml.sh                  # Copy mzML files with manifest generation
│   ├── extract-d.sh                  # Extract .d archives with manifest generation
│   ├── fragpipe-headless.sh          # FragPipe headless execution
│   ├── fragpipe-pdv.py               # PDV plotting from filtered peptides
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

The primary workflow that processes proteomics data from mounted directories or direct file inputs. Supports .raw, .mzML.gz, .mzML, and Bruker timsTOF .d input; set the type with the required `input_type` parameter.

FragPipe supports a comprehensive set of workflow configurations available in the [FragPipe workflows repository](https://github.com/Nesvilab/FragPipe/tree/develop/workflows), including workflows for various quantitation methods (TMT, SILAC, LFQ, DIA, iTRAQ), post-translational modifications (phosphorylation, ubiquitination, acetylation, glycosylation), and specialized analyses (HLA peptidome, ABPP, open search).

**Steps:**
1. **Convert/Process files** (one step runs, selected by `input_type`):
   - **Convert .raw to .mzML**: Use msconvert if input is .raw files
   - **Decompress .mzML.gz**: Gunzip if input is compressed mzML files
   - **Copy .mzML**: Direct copy if input is already uncompressed mzML
   - **Extract .d**: Extract Bruker timsTOF runs from `.d.zip` / `.d.tar` / `.d.tar.gz` / `.d.tgz` archives (read natively by MSFragger, no conversion)
2. **Prepare database**: Add decoys and contaminants to custom FASTA using Philosopher
3. **Filter canonical peptides**: Remove canonical peptides by gene symbols (skip with `skip_canonical_filter: true` to keep wild-type sequences in the database)
4. **Run FragPipe**: Execute FragPipe in headless mode with prepared database
5. **Optional control-overlap filtering**: Build tumor-specific input/control sets from non-canonical, non-decoy peptides, apply mutation-position overlap gating (`peptMutPos` / `Protein_fusion_site`; splice IDs exempt), then remove input peptides overlapping control peptides (exact match or containment)
6. **Optional PDV plotting**: Use original PDV CLI to generate spectrum PDFs for peptides in `*_combined_peptide_control_filtered.tsv`

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

Set `input_type` to match your files (`raw`, `mzml_gz`, `mzml`, or `d`); the workflow runs the matching copy/conversion step. Follow these steps:

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

**For Bruker timsTOF runs** (one archive per run, flat or in experiment subfolders):
```
source_dir/
├── run_001.d.zip
├── run_002.d.tar.gz
└── run_003.d.tgz                 # .d.zip, .d.tar, .d.tar.gz or .d.tgz
```
Each archive must contain a single top-level `<run>.d/` folder with `analysis.tdf` (and `analysis.tdf_bin`), or the step fails. Uncompressed `.d` folders are not accepted; archive them first (e.g. `zip -0 -r run_001.d.zip run_001.d`). This matches the archived-run naming in the proteomics and immunopeptidomics manifests ([manifest-template](https://github.com/childrens-bti/manifest-template)).

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
  - `chr12:122939864_122940284_ABCB9_phase1`

Field notes:

- `ENSG...` = gene ID, `ENST...` = transcript ID, `ENSP...` = protein ID
- `c.` fields are coding-DNA changes (HGVS-like), `p.` fields are protein changes
- `peptMutPos=<N>` marks mutation position used in peptide/protein context
- `Protein_fusion_site:<N>` is the amino-acid fusion junction position
- `phase0/1/2` indicates translation frame for splice-derived entries (junction or target)

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

input_source_dir:
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

# Optional: run PDV spectrum plotting for filtered peptides
run_pdv: false
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

input_source_dir:
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

**For Bruker timsTOF .d archives:**
```yaml
input_type: "d"
input_source_dir:
  class: Directory
  path: /path/to/source_dir       # Directory with <run>.d.zip/.d.tar/.d.tar.gz/.d.tgz archives (flat or per-experiment subfolders)

# HLA class I immunopeptidomics: nonspecific search, peptide length 8-15
# (FragPipe 22.0 Nonspecific-HLA template with digest length changed from 7-25)
workflow_file:
  class: File
  path: $(pwd)/data/workflow_files/Nonspecific-HLA-classI_v22.workflow.txt

# Optional: keep canonical (wild-type) proteins of query genes in the database
skip_canonical_filter: true
# ... rest same as .mzML example
```
Manifest column 2 is the run name without `.d` or the archive extension (e.g. `run_001` for `run_001.d.zip`); column 4 (`DDA` or `DIA`) is kept and defaults to `DDA`.

Notes for `.d` input:
- The image must include MSFragger's `ext/` folder (see [Docker Image](#docker-image)); without it MSFragger reports `Scans = 0`.
- `run_pdv` is not supported yet: `fragpipe-pdv.py` looks for `<run>.mzML`, while `.d` runs only produce `<run>_uncalibrated.mzML`.
- The control filter's mutation-position gating reads `peptMutPos` / `Protein_fusion_site` from query FASTA headers; peptides from custom FASTA entries without these tags (such as minigene constructs) are all kept, whether or not they cover a mutation.

> **Note:** `input_source_dir` holds the input data for every `input_type` (`.raw`, `.mzML.gz`, `.mzML`, or `.d` archives). It was called `mzml_source_dir` before v1.2.0; params files written for older releases need this key renamed.

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
2. **Column 2 must match filenames exactly** (without extension; for `.d` input, the run name without `.d` or the archive extension)
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
| **Input Type Routing** | `input_type` (`raw`, `mzml_gz`, `mzml`, `d`) selects the matching conversion/copy step |
| **Raw File Support** | Converts Thermo Fisher .raw files using msconvert from ProteoWizard |
| **Bruker timsTOF Support** | `input_type: "d"` extracts `.d.zip` / `.d.tar` / `.d.tar.gz` / `.d.tgz` archives and searches the `.d` runs natively (no conversion); PDV plotting is not supported for `.d` yet |
| **Optional Canonical Filter** | `skip_canonical_filter: true` keeps wild-type proteins in the database (e.g. minigene / immunopeptidomics searches) |
| **Automatic Manifest Generation** | Builds the FragPipe manifest with local paths from the processed files; the input manifest (column 2 = run names) is still required |
| **Subset Processing** | With `run_subset: true`, process only files under a folder named `subset_pattern` |
| **TMT Annotation Support** | Automatically copies `annotation.txt` files from experiment directories |
| **Dynamic FASTA Injection** | Workflow file updated at runtime with correct FASTA path |
| **Mutation-Position Gating** | Optional control filter keeps variant/fusion peptides only when peptide `Start`-`End` overlaps `peptMutPos` or `Protein_fusion_site` (splice IDs exempt) |
| **Writable mzML Directory** | Uses `InplaceUpdateRequirement` for FragPipe temporary files |
| **Hardcoded Binary Paths** | No PATH dependencies, uses absolute paths to Philosopher and FragPipe |
| **SBFS Mount Support** | Direct mounting of Cavatica projects for local execution |
| **Backward Compatible** | Maintains `skip_gunzip` parameter for existing workflows |

## Docker Image

**Image:** `pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:v1.2.0` (the tag referenced by every FragPipe tool in `tools/*.cwl`)

**Image tags follow releases:** each fragpipe_cwl release pins its own image tag, named after the release (e.g. `v1.2.0`), because `scripts/` is built into the image. A release's tag is never overwritten. When `scripts/` or the `Dockerfile` changes, build and push a new tag and update `dockerPull` in `tools/*.cwl` to match. Releases before v1.2.0 use `fragpipe_v22`, which is kept at the pre-v1.2.0 image.

**Contents:**
- FragPipe 22.0 at `/fragpipe_bin/fragPipe-22.0/fragpipe/`
- Philosopher v5.1.1 at `/fragpipe_bin/fragPipe-22.0/fragpipe/tools/Philosopher/philosopher-v5.1.1`
- MSFragger and other FragPipe tools
- Original PDV 2.2.3 at `/opt/pdv/PDV.jar` for batch spectrum plotting
- `xvfb-run` for virtual-display execution of PDV CLI inside Docker
- Shell scripts at `/opt/impact_trial/scripts/`

**License-required tools in the main FragPipe image:**
- **IonQuant**, **MSFragger**, and **diaTracer** (download/license details: [FragPipe wiki](https://github.com/rokitalab/fragpipe/wiki))
- License instruction status: required wiki instructions were followed and corresponding license agreements/download steps were completed
- **MSFragger native readers** (`ext/` folder from the licensed MSFragger 4.1 zip, including `ext/bruker/libtimsdata-2-21-0-4.so`): place at `tools/ext/` before building; required for Bruker `.d` input. `tools/ext/` is gitignored.

**For .raw file conversion**, you also need:
- **MSConvert Docker Image**: `chambm/pwiz-skyline-i-agree-to-the-vendor-licenses`
  - Contains ProteoWizard msconvert tool
  - Includes wine for running Windows-based msconvert
  - Used only for the `msconvert-raw.cwl` step

**Building:**
```bash
docker build -t pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:v1.2.0 .
docker push pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:v1.2.0
```

## Requirements

- **CWL Runner**: cwltool 3.1+ (for CWL v1.2 support including `InplaceUpdateRequirement`)
- **Docker**: For containerized execution
  - Main FragPipe image: `pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:v1.2.0`
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
├── SAMPLE001_combined_peptide_control_filtered.tsv # Input tumor-specific peptides after control overlap filtering (optional)
├── SAMPLE001_input_tumor_specific_peptides.tsv     # Input tumor-specific rows after mutation-position gating (optional)
├── SAMPLE001_control_tumor_specific_peptides.tsv   # Control tumor-specific rows after mutation-position gating (optional)
├── SAMPLE001_control_overlap_summary.txt           # Control-filter summary including mutation/overlap counts (optional)
├── SAMPLE001_pdv_spectra/                          # PDV batch output directory (optional)
│   ├── <sample_name>/                              # Per-sample PDV PDFs and scan list
│   └── pdv_summary.tsv                             # Run-level summary (peptide/scans plotted)
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

`SAMPLE001_control_overlap_summary.txt` includes:

- `input_total_peptides`
- `input_tumor_specific_peptides`
- `control_total_peptides`
- `control_tumor_specific_peptides`
- `tumor_specific_filtered_by_mutation_position`
- `control_tumor_specific_filtered_by_mutation_position`
- `tumor_specific_overlap_filtered`
- `final_peptides_left`

### Major Control-Filter Outputs (How to Read Them)

For runs with `control_combined_peptide` enabled, these are the main files to review in order:

1. `SAMPLE001_combined_peptide.tsv`
  - Full peptide-level FragPipe result before optional control filtering.
  - Use as the baseline population (`input_total_peptides`).

2. `SAMPLE001_input_tumor_specific_peptides.tsv`
  - Input tumor-specific set after gating:
    - non-canonical / non-decoy (`Protein` not starting with `sp|`, `tr|`, `rev_`),
    - non-empty peptide sequence,
    - mutation-position overlap when present (`Start`-`End` overlaps `peptMutPos` or `Protein_fusion_site`),
    - splice-derived IDs (junction and target forms with `phase0/1/2`) are exempt from mutation-position gating.

3. `SAMPLE001_control_tumor_specific_peptides.tsv`
  - Control tumor-specific set built with the same gating logic as input.
  - This is the reference set used for overlap removal.

4. `SAMPLE001_combined_peptide_control_filtered.tsv`
  - Final kept peptides: input tumor-specific peptides after removing overlap with control tumor-specific peptides.
  - Overlap definition is: exact match OR containment (`A==B`, `A in B`, or `B in A`).

5. `SAMPLE001_control_overlap_summary.txt`
  - Audit trail for the filtering flow:
    - starting totals (`input_total_peptides`, `control_total_peptides`),
    - tumor-specific counts after gating (`input_tumor_specific_peptides`, `control_tumor_specific_peptides`),
    - rows removed by mutation-position gating,
    - rows removed by control overlap,
    - final retained count (`final_peptides_left`).

Recommended validation check:
- `final_peptides_left = input_tumor_specific_peptides - tumor_specific_overlap_filtered`

## Credits

This CWL workflow implementation is based on the [FragPipe](https://github.com/Nesvilab/FragPipe) pipeline developed by [Nesvilab](https://github.com/Nesvilab). FragPipe provides an integrated environment for MS/MS proteomics data analysis and includes the following components:

- **MSFragger**: Fast peptide MS/MS database search engine
- **Philosopher**: Downstream proteomics data validation and analysis
- **IonQuant**: Peptide quantification tool
- **diaTracer**: DIA data processing

For more information about FragPipe workflows and available analysis configurations, see the [workflows directory](https://github.com/Nesvilab/FragPipe/tree/develop/workflows) in the FragPipe repository.

