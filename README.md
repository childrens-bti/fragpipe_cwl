# FragPipe CWL Workflows

This directory contains Common Workflow Language (CWL) implementations of the FragPipe proteomics analysis pipeline.

## Structure

```
fragpipe_cwl/
├── Dockerfile                         # Container with FragPipe and dependencies
├── run_fragpipe.sh                   # Original bash script (reference)
├── fragpipe-local.cwl                # Main workflow for local execution with SBFS mounting
├── fragpipe-cavatica.cwl             # Main workflow for Cavatica platform execution
├── tools/                            # CWL CommandLineTool definitions
│   ├── philosopher-database.cwl      # Add decoys/contaminants to FASTA
│   ├── filter-canonical-peptides.cwl # Filter canonical peptides by gene symbols
│   ├── fragpipe-headless.cwl         # Main FragPipe execution
│   └── sbfs-mount-copy.cwl           # Mount Cavatica project (local only)
└── workflows/                        # Additional CWL sub-workflows (if any)
```

## Workflows

### 1. Local Execution Workflow (`fragpipe-local.cwl`)

Use this workflow for **local testing** when you need to mount Cavatica projects via SBFS to access large mzML file collections.

**Steps:**
1. Mount Cavatica project using SBFS
2. Copy and unzip mzML files
3. Prepare FASTA database (add decoys/contaminants)
4. Filter canonical peptides
5. Run FragPipe headless

**Required Inputs:**
- `query_fasta`: Custom FASTA file
- `uniprot_canonical_fasta`: UniProt canonical FASTA (gzipped)
- `workflow_file`: FragPipe workflow configuration
- `manifest_file`: FragPipe manifest file
- `cohort`: "hope" or "cptac"
- `run_subset`: true/false (optional, default: false)

### 2. Cavatica Platform Workflow (`fragpipe-cavatica.cwl`)

Use this workflow when **running directly on Cavatica platform** where files are already accessible.

**Steps:**
1. Prepare FASTA database (add decoys/contaminants)
2. Filter canonical peptides
3. Run FragPipe headless

**Required Inputs:**
- `query_fasta`: Custom FASTA file
- `uniprot_canonical_fasta`: UniProt canonical FASTA (gzipped)
- `workflow_file`: FragPipe workflow configuration
- `manifest_file`: FragPipe manifest file
- `mzml_files`: Array of mzML files from Cavatica storage

## Usage

### Local Execution

```bash
cwl-runner workflows/fragpipe-local.cwl inputs-local.yml
```

Example `inputs-local.yml`:
```yaml
query_fasta:
  class: File
  path: input/custom.fasta
uniprot_canonical_fasta:
  class: File
  path: refs/UP000005640_9606.fasta.gz
workflow_file:
  class: File
  path: input/PDC000180customworkflow.workflow
manifest_file:
  class: File
  path: input/PDC000180filesmanifest.fp-manifest
cohort: "cptac"
run_subset: false
```

### Cavatica Platform Execution

```bash
cwl-runner workflows/fragpipe-cavatica.cwl inputs-cavatica.yml
```

Example `inputs-cavatica.yml`:
```yaml
query_fasta:
  class: File
  path: input/custom.fasta
uniprot_canonical_fasta:
  class: File
  path: refs/UP000005640_9606.fasta.gz
workflow_file:
  class: File
  path: input/PDC000180customworkflow.workflow
manifest_file:
  class: File
  path: input/PDC000180filesmanifest.fp-manifest
mzml_files:
  - class: File
    path: /sbgenomics/project-files/sample1.mzML
  - class: File
    path: /sbgenomics/project-files/sample2.mzML
```

## Building the Docker Image

```bash
# Build locally
docker build -t pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest .

# Push to registry
docker push pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest
```

## Tool Descriptions

### philosopher-database.cwl
Initializes a Philosopher workspace and adds decoys/contaminants from UniProt canonical database to the custom FASTA file.

### filter-canonical-peptides.cwl
Extracts gene symbols from the custom FASTA and filters out canonical peptides annotated to those genes.

### fragpipe-headless.cwl
Runs FragPipe in headless mode with specified workflow, manifest, and processed FASTA database.

### sbfs-mount-copy.cwl
Mounts a Cavatica project using SBFS, copies mzML files, and unzips them. **Local execution only**.

## Key Differences Between Workflows

| Feature | Local Workflow | Cavatica Workflow |
|---------|----------------|-------------------|
| SBFS Mounting | ✅ Yes | ❌ No |
| mzML Input | Via mounted filesystem | Direct file inputs |
| Use Case | Local testing/development | Production on Cavatica |
| Network Access | Required (for SBFS) | Not required |

## Requirements

- CWL runner (cwltool, toil, arvados-cwl-runner, etc.)
- Docker (for local execution)
- SBFS installed (for local workflow only)
- Cavatica account and credentials (for local workflow)

## Notes

- The Docker image includes FragPipe 23.1 with all required tools
- JAR files (MSFragger, IonQuant, diaTracer) must be copied during Docker build
- Resource requirements are specified as hints for Cavatica platform optimization
