 # template for developing cwl workflows

This repository contains CWL tools and workflows for XXX. The workflow will be packaged and tested on an EC2 instance:

## Overview of Workflows (Example)

### `merge-rsem-gene.cwl`
- **Input:** `*.rsem.genes.results.gz`
- **Output:**  
  - `gene-expression-rsem-fpkm.all.rds`
  - `gene-expression-rsem-tpm.all.rds`
  - `gene-counts-rsem-expected_count.all.rds`

### `prep.sh`
- **Purpose:** Orchestrates all the above workflows, handles S3 mounting, manifest creation, reference file download.

### `main_workflow.cwl`
- **Purpose:** Main workflow wrapper.

## Repository Structure

```
template_cwl
├── tools/                   # CWL CommandLineTool definitions
├── scripts/                 # R/python scripts for the merge tools   
├── workflows/               # CWL workflows/subworkflows
├── data/                    # Input data to run on
├── test/                    # Test scripts and expected outputs
├── manifests/               # intermediate manifest files 
├── params/                  # workflow input parameter yaml files
├── outputs/                 # workflow output files
├── logs/                    # running log files
├── envs/                    # Conda environments with tools for local testing
├── README.md
├── LICENSE
└── .gitignore
```

## Usage

### Prerequisites

- AWS CLI with SSO configuration follow [these steps](https://childrens-bti.github.io/bti-bfx-docs/aws/), make sure you have permission to the S3 buckets hosting harmonization results.
- `jq`, `curl`, `cwltool`, and `mount-s3` installed
- Access to the relevant S3 bucket with harmonized data

#### FUSE Configuration for S3 Mounts

To allow Docker and other users to access your S3 mount, you must enable the `allow_other` option for FUSE.  
**Edit `/etc/fuse.conf` and ensure the following line is present and uncommented:**

```bash
sudo vim /etc/fuse.conf
```
Uncomment or add:
```
user_allow_other
```
Save and exit the editor.

This is required so that `mount-s3 --allow-other ...` works and Docker can access the mounted S3 bucket.

### Setup Conda Environment

First, create and activate the conda environment with all required tools:

```bash
conda env create -f envs/cwl_env.yml
conda activate cwl_env
```

### Run Locally on EC2

After activating the environment, run the main workflow script:
```bash
bash prep.sh -h
Usage: prep.sh [BUCKET] [BUCKET_PREFIX] [OUT_DIR] [LOG_DIR]

Arguments:
  BUCKET         S3 bucket name (example: bti-private-us-east-1-prd-gilbert-lab)
  BUCKET_PREFIX  S3 prefix/path (example: harmonized/MTAP/)
  OUT_DIR        Output directory (default: outputs/merged)
  LOG_DIR        Log directory (default: logs)
```
Run:
```bash
bash prep.sh bti-private-us-east-1-prd-gilbert-lab harmonized/MTAP/ outputs/merged logs

cwltool --outdir outputs/merged/ rnaseq_merge_workflow.cwl params/rnaseq_merge_workflow_params.yml > logs/rnaseq_merge_workflow.log 2>&1
```

### Run on Cavatica

Copy the app and the references to your project and run it on Cavatica platform.


### Example Parameter Files

See the [`params/`](params/) directory for example YAML parameter files for each workflow.

## Inputs

- Input files (e.g., RSEM, HTSeq, STAR counts)
- Reference files:
- Example input data:  

## Outputs (example)
- Merged gene expression and isoform expression tables
- Merged and collapsed RNA-Seq quantification matrices
- Merged fusion and splicing event tables

## Acknowledgments

Workflow based on previous work: 

## Maintainer

Chao Di ([@chaodi51](https://github.com/chaodi51))