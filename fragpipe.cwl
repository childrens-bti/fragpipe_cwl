cwlVersion: v1.2
class: Workflow

label: FragPipe Proteomics Pipeline
doc: |
  Complete FragPipe proteomics analysis pipeline for both LOCAL and CAVATICA execution.
  This workflow can process .raw, .mzML.gz, .mzML files, and Bruker timsTOF .d runs
  (archived as <run>.d.zip, .d.tar, .d.tar.gz or .d.tgz).
  It performs FASTA preparation with decoys/contaminants and runs FragPipe analysis.
  Input type must be specified: "raw", "mzml_gz", "mzml", or "d".

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
  
  # Input data source (mounted Cavatica or S3 directory)
  input_source_dir:
    type: Directory
    doc: |
      Directory containing input files: .raw, .mzML.gz, .mzML, or Bruker
      .d.zip/.d.tar/.d.tar.gz/.d.tgz archives (renamed from mzml_source_dir in v1.2.0).

  input_type:
    type: string
    doc: Type of input files - must be one of "raw", "mzml_gz", "mzml", or "d"

  skip_canonical_filter:
    type: boolean
    default: false
    doc: |
      If true, skip removing canonical proteins of genes named in query_fasta headers,
      so wild-type sequences stay in the database and compete with query sequences.

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
      Works for all input types: .raw, .mzML.gz, .mzML and .d archives.
      All input types should be organized in the same experiment folder structure.
      Not required when run_subset is false.

  output_basename:
    type: string
    doc: Base name for all output files (e.g., "SAMPLE001_N849")

  control_combined_peptide:
    type: File?
    default: null
    doc: Optional control-run combined peptide table used to remove overlapping peptides

  run_pdv:
    type: boolean
    default: false
    doc: |
      If true, run PDV batch plotting on peptides from *_combined_peptide_control_filtered.tsv.
      Ignored for input_type "d" (PDV is skipped for Bruker .d runs).

  num_cores:
    type: int
    default: 8
    doc: Number of parallel processes for msconvert .raw file conversion

outputs:
  results_dir:
    type: Directory
    outputSource: run_fragpipe/results_dir
    doc: Full FragPipe results directory, including per-sample intermediate folders/files

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

  pdv_spectra_dir:
    type: Directory?
    outputSource: run_pdv_plots/pdv_spectra_dir
    doc: Optional PDV spectrum plot directory built from filtered combined peptides

steps:
  # Step 1a: Convert .raw files to mzML (if input is .raw)
  convert_raw:
    run: tools/msconvert-raw.cwl
    when: $(inputs.input_type === "raw")
    in:
      input_type: input_type
      raw_source_dir: input_source_dir
      run_subset:
        source: run_subset
        valueFrom: '$(self ? "true" : "false")'
      subset_pattern: subset_pattern
      manifest_file: manifest_file
      num_cores: num_cores
    out: [input_directory, input_file_list, input_manifest]

  # Step 1b: Gunzip mzML files (if input is .mzML.gz)
  gunzip_mzml:
    run: tools/gunzip-mzml.cwl
    when: $(inputs.input_type === "mzml_gz")
    in:
      input_type: input_type
      input_source_dir: input_source_dir
      run_subset:
        source: run_subset
        valueFrom: '$(self ? "true" : "false")'
      subset_pattern: subset_pattern
      manifest_file: manifest_file
    out: [input_directory, input_file_list, input_manifest]

  # Step 1c: Copy mzML files (if input is already .mzML)
  copy_mzml:
    run: tools/copy-mzml.cwl
    when: $(inputs.input_type === "mzml")
    in:
      input_type: input_type
      input_source_dir: input_source_dir
      run_subset:
        source: run_subset
        valueFrom: '$(self ? "true" : "false")'
      subset_pattern: subset_pattern
      manifest_file: manifest_file
    out: [input_directory, input_file_list, input_manifest]

  # Step 1d: Extract Bruker .d runs from .d.zip/.d.tar* archives (if input is timsTOF .d)
  extract_d:
    run: tools/extract-d.cwl
    when: $(inputs.input_type === "d")
    in:
      input_type: input_type
      input_source_dir: input_source_dir
      run_subset:
        source: run_subset
        valueFrom: '$(self ? "true" : "false")'
      subset_pattern: subset_pattern
      manifest_file: manifest_file
    out: [input_directory, input_file_list, input_manifest]

  # Step 2: Add decoys and contaminants to FASTA
  prepare_database:
    run: tools/philosopher-database.cwl
    in:
      query_fasta: query_fasta
      uniprot_canonical_fasta: uniprot_canonical_fasta
    out: [fasta_with_decoys]
    
  # Step 3: Filter canonical peptides (skipped when skip_canonical_filter is true)
  filter_canonical:
    run: tools/filter-canonical-peptides.cwl
    when: $(inputs.skip_canonical_filter !== true)
    in:
      skip_canonical_filter: skip_canonical_filter
      query_fasta: query_fasta
      fasta_with_decoys: prepare_database/fasta_with_decoys
    out: [filtered_fasta, gene_symbols]

  # Step 4: Run FragPipe headless
  run_fragpipe:
    run: tools/fragpipe-headless.cwl
    in:
      filtered_fasta:
        source: [filter_canonical/filtered_fasta, prepare_database/fasta_with_decoys]
        pickValue: first_non_null
      workflow_file: workflow_file
      output_basename: output_basename
      manifest_file:
        source: [convert_raw/input_manifest, gunzip_mzml/input_manifest, copy_mzml/input_manifest, extract_d/input_manifest]
        pickValue: first_non_null
      input_directory:
        source: [convert_raw/input_directory, gunzip_mzml/input_directory, copy_mzml/input_directory, extract_d/input_directory]
        pickValue: first_non_null
    out:
      - input_directory_out
      - results_dir
      - combined_protein
      - combined_peptide
      - workflow_file_out
      - manifest_file_out

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

  # Step 6: Optional PDV plotting for control-filtered peptides
  # (skipped for .d input: those runs have no <run>.mzML for PDV)
  run_pdv_plots:
    run: tools/fragpipe-pdv.cwl
    when: $(inputs.run_pdv === true && inputs.control_combined_peptide !== null && inputs.input_type !== "d")
    in:
      input_type: input_type
      run_pdv: run_pdv
      control_combined_peptide: control_combined_peptide
      results_dir: run_fragpipe/results_dir
      input_directory: run_fragpipe/input_directory_out
      target_peptide_table: filter_control_peptides/filtered_combined_peptide
      output_basename: output_basename
    out:
      - pdv_spectra_dir


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
- id: "https://github.com/childrens-bti/fragpipe_cwl/releases/tag/v1.2.0" # update with stable release in Cavatica
  label: github-release
