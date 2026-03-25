cwlVersion: v1.2
class: Workflow

label: FragPipe Proteomics Pipeline (fragpipe v24)
doc: |
  Complete FragPipe proteomics analysis pipeline for both LOCAL and CAVATICA execution.
  
  **Version:** FragPipe v24.0-build27 (updated from v22/v23)
  
  **Supported input formats:** .raw, .mzML.gz, and .mzML files with automatic detection.
  Input type must be specified: "raw", "mzml_gz", or "mzml".
  
  **Key workflow steps:**
  1. Auto-detect input file type (raw/mzML.gz/mzML)
  2. Convert/decompress files as needed using msconvert + gunzip
  3. Prepare database with FASTA decoys/contaminants via Philosopher
  4. Filter canonical peptides by gene symbol
  5. Run FragPipe headless with dynamic FASTA injection
  6. Optional: Apply mutation-position gating and control-peptide overlap filtering on tumor-specific variants
  
  **[v24 changes for DDA]**
  - IonQuant intensity mode now explicit (set to mode 0 for v22-like abundance scaling)
  - MSBooster now includes IM prediction for instruments with ion mobility data (inactive for regular MS)
  - Expanded MSFragger parameters (digest-only, labile-fragment handling) for advanced search scenarios
  - New MBG (Motif-x Biomarker Generation) and transfer-learning blocks (disabled by default)
  - See docs/impact002-lfq-mbr-parameter-changes.md for complete v22 vs v24 delta
  
  **For regular DDA on non-IM instruments:** Core search/quant settings remain aligned with v22 workflows.
  Precursor mass tolerance, enzyme, modifications, and percolator thresholds are backward compatible.
  
  This workflow performs FASTA preparation with decoys/contaminants and runs FragPipe analysis.

requirements:
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}

inputs:
  # FASTA inputs
  query_fasta:
    type: File
    doc: Custom FASTA file containing query peptides (e.g., data/custom.fasta)
    
  uniprot_canonical_fasta:
    type: File
    doc: UniProt canonical FASTA file (e.g., data/reference/UP000005640_9606.fasta.gz)
    
  # FragPipe inputs
  workflow_file:
    type: File
    doc: FragPipe workflow configuration file (e.g., data/HOPEproteome_TMT11workflow.workflow)
    
  manifest_file:
    type: File
    doc: FragPipe manifest file specifying mzML file paths (e.g., data/HOPEproteome_TMT11.fp-manifest)
  
  # mzML/raw source (mounted Cavatica or S3 directory)
  mzml_source_dir:
    type: Directory
    doc: Directory containing input files (.raw, .mzML.gz, or .mzML)

  input_type:
    type: string
    doc: Type of input files - must be one of "raw", "mzml_gz", or "mzml"
    
  run_subset:
    type: boolean
    default: false
    doc: If true, only process files matching subset_pattern

  subset_pattern:
    type: string?
    default: ""
    doc: |
      Full experiment or patient folder name to match when run_subset is true.
      Matches directory path in the folder structure (e.g., "N849" matches */N849/*)
      Works for all input types: .raw, .mzML.gz, and .mzML files.
      Raw files should be organized in the same folder structure as mzML files.
      Not required when run_subset is false.

  output_basename:
    type: string
    doc: Base name for all output files (e.g., "SAMPLE001_N849")

  control_combined_peptide:
    type: File?
    default: null
    doc: Optional control-run combined peptide table used to remove overlapping peptides

outputs:
  combined_protein:
    type: File?
    outputSource: run_fragpipe/combined_protein
    doc: Combined protein quantification results
    
  combined_peptide:
    type: File?
    outputSource: run_fragpipe/combined_peptide
    doc: Combined peptide quantification results

  filtered_combined_peptide:
    type: File?
    outputSource: filter_control_peptides/filtered_combined_peptide
    doc: Optional combined peptide output with control-overlap filtering applied

  input_tumor_specific_peptides:
    type: File?
    outputSource: filter_control_peptides/input_tumor_specific_peptides
    doc: Optional input-run tumor-specific peptide rows (non-canonical, non-decoy)

  control_tumor_specific_peptides:
    type: File?
    outputSource: filter_control_peptides/control_tumor_specific_peptides
    doc: Optional control-run tumor-specific peptide rows (non-canonical, non-decoy)

  control_overlap_summary:
    type: File?
    outputSource: filter_control_peptides/control_overlap_summary
    doc: Summary statistics for control-overlap filtering

  combined_modified_peptide:
    type: File?
    outputSource: run_fragpipe/combined_modified_peptide
    doc: Combined modified peptide quantification results
    
  combined_ion:
    type: File?
    outputSource: run_fragpipe/combined_ion
    doc: Combined ion quantification results

  tmt_report:
    type: Directory?
    outputSource: run_fragpipe/tmt_report
    doc: TMT reporter ion quantification results

  workflow_file_out:
    type: File?
    outputSource: run_fragpipe/workflow_file_out
    doc: FragPipe workflow configuration used

  fragger_params:
    type: File?
    outputSource: run_fragpipe/fragger_params
    doc: MSFragger parameter file

  tmt_integrator_conf:
    type: File?
    outputSource: run_fragpipe/tmt_integrator_conf
    doc: TMT-Integrator configuration file

  experiment_annotation:
    type: File?
    outputSource: run_fragpipe/experiment_annotation
    doc: Experiment annotation file

  sdrf_file:
    type: File?
    outputSource: run_fragpipe/sdrf_file
    doc: SDRF metadata file

  manifest_file_out:
    type: File?
    outputSource: run_fragpipe/manifest_file_out
    doc: FragPipe manifest file used

  log_file:
    type: File?
    outputSource: run_fragpipe/log_file
    doc: FragPipe execution log file

steps:
  # Step 1a: Convert .raw files to mzML (if input is .raw)
  convert_raw:
    run: tools/msconvert-raw.cwl
    when: $(inputs.input_type === "raw")
    in:
      input_type: input_type
      raw_source_dir: mzml_source_dir
      run_subset:
        source: run_subset
        valueFrom: '$(self ? "true" : "false")'
      subset_pattern: subset_pattern
      manifest_file: manifest_file
    out: [mzml_directory, mzml_file_list, mzml_manifest]

  # Step 1b: Gunzip mzML files (if input is .mzML.gz)
  gunzip_mzml:
    run: tools/gunzip-mzml.cwl
    when: $(inputs.input_type === "mzml_gz")
    in:
      input_type: input_type
      mzml_source_dir: mzml_source_dir
      run_subset:
        source: run_subset
        valueFrom: '$(self ? "true" : "false")'
      subset_pattern: subset_pattern
      manifest_file: manifest_file
    out: [mzml_directory, mzml_file_list, mzml_manifest]

  # Step 1c: Copy mzML files (if input is already .mzML)
  copy_mzml:
    run: tools/copy-mzml.cwl
    when: $(inputs.input_type === "mzml")
    in:
      input_type: input_type
      mzml_source_dir: mzml_source_dir
      run_subset:
        source: run_subset
        valueFrom: '$(self ? "true" : "false")'
      subset_pattern: subset_pattern
      manifest_file: manifest_file
    out: [mzml_directory, mzml_file_list, mzml_manifest]
    
  # Step 2: Add decoys and contaminants to FASTA
  prepare_database:
    run: tools/philosopher-database.cwl
    in:
      query_fasta: query_fasta
      uniprot_canonical_fasta: uniprot_canonical_fasta
    out: [fasta_with_decoys]
    
  # Step 3: Filter canonical peptides
  filter_canonical:
    run: tools/filter-canonical-peptides.cwl
    in:
      query_fasta: query_fasta
      fasta_with_decoys: prepare_database/fasta_with_decoys
    out: [filtered_fasta, gene_symbols]
    
  # Step 4: Run FragPipe headless
  run_fragpipe:
    run: tools/fragpipe-headless.cwl
    in:
      filtered_fasta: filter_canonical/filtered_fasta
      workflow_file: workflow_file
      output_basename: output_basename
      manifest_file:
        source: [convert_raw/mzml_manifest, gunzip_mzml/mzml_manifest, copy_mzml/mzml_manifest]
        pickValue: first_non_null
      mzml_directory:
        source: [convert_raw/mzml_directory, gunzip_mzml/mzml_directory, copy_mzml/mzml_directory]
        pickValue: first_non_null
    out:
      - combined_protein
      - combined_peptide
      - combined_modified_peptide
      - combined_ion
      - tmt_report
      - workflow_file_out
      - fragger_params
      - tmt_integrator_conf
      - experiment_annotation
      - sdrf_file
      - manifest_file_out
      - log_file

  # Step 5: Optional filtering to remove peptides observed in control runs
  filter_control_peptides:
    run: tools/filter-control-peptides.cwl
    when: $(inputs.control_combined_peptide !== null)
    in:
      input_combined_peptide: run_fragpipe/combined_peptide
      control_combined_peptide: control_combined_peptide
      output_basename: output_basename
    out:
      - filtered_combined_peptide
      - input_tumor_specific_peptides
      - control_tumor_specific_peptides
      - control_overlap_summary


$namespaces:
  sbg: "https://sevenbridges.com/"
hints:
- class: "sbg:maxNumberOfParallelInstances"
  value: 4
- class: ResourceRequirement
  ramMin: 131072
  coresMin: 16
- class: sbg:AWSInstanceType
  value: "m5.8xlarge"

"sbg:links":
- id: "https://github.com/childrens-bti/fragpipe_cwl/tree/feature/handle_.raw_input" # will update with stable release
  label: github-release
