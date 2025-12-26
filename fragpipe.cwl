cwlVersion: v1.2
class: Workflow

label: FragPipe Proteomics Pipeline
doc: |
  Complete FragPipe proteomics analysis pipeline for both LOCAL and CAVATICA execution.
  This workflow expects a mounted Cavatica directory containing gzipped mzML files,
  performs FASTA preparation with decoys/contaminants, and runs FragPipe analysis.

requirements:
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  SubworkflowFeatureRequirement: {}

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
  
  # mzML source (mounted Cavatica directory)
  mzml_source_dir:
    type: Directory
    doc: Mounted Cavatica directory containing gzipped mzML files
    
  run_subset:
    type: boolean
    default: false
    doc: If true, only process first experiment (01C prefix)

  results_dir:
    type: string
    doc: Output directory for FragPipe results (relative to runtime working dir)

outputs:
  results_directory:
    type: Directory
    outputSource: run_fragpipe/results_directory
    doc: FragPipe results directory

  combined_protein:
    type: File?
    outputSource: run_fragpipe/combined_protein
    doc: Combined protein quantification results
    
  combined_peptide:
    type: File?
    outputSource: run_fragpipe/combined_peptide
    doc: Combined peptide quantification results

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
  # Step 1: Gunzip mzML files from mounted Cavatica directory
  gunzip_mzml:
    run: tools/gunzip-mzml.cwl
    in:
      mzml_source_dir: mzml_source_dir
      run_subset:
        source: run_subset
        valueFrom: '$(self ? "true" : "false")'
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
      manifest_file: gunzip_mzml/mzml_manifest
      mzml_directory: gunzip_mzml/mzml_directory
      results_dir: results_dir
    out:
      - results_directory
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


$namespaces:
  sbg: "https://sevenbridges.com/"
hints:
- class: "sbg:maxNumberOfParallelInstances"
  value: 4
- class: ResourceRequirement
  ramMin: 131072
  coresMin: 16
- class: sbg:AWSInstanceType
  value: "r5.4xlarge"

"sbg:links":
- id: "https://github.com/childrens-bti/fragpipe_cwl/tree/workflow_sketch" # will update with stable release
  label: github-release
