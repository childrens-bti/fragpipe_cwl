cwlVersion: v1.2
class: Workflow

label: FragPipe Proteomics Pipeline - Cavatica Platform
doc: |
  Complete FragPipe proteomics analysis pipeline for CAVATICA PLATFORM execution.
  This workflow skips SBFS mounting and expects mzML files to be provided
  as direct inputs from the Cavatica platform storage.
  
  Use this workflow when running directly on Cavatica where files are
  already accessible without mounting.

requirements:
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}

inputs:
  # FASTA inputs
  query_fasta:
    type: File
    doc: Custom FASTA file containing query peptides
    sbg:fileTypes: "FASTA, FA, FAS"
    
  uniprot_canonical_fasta:
    type: File
    doc: UniProt canonical FASTA file (gzipped), e.g., UP000005640_9606.fasta.gz
    sbg:fileTypes: "FASTA.GZ, FA.GZ, FAS.GZ"
    
  # FragPipe inputs
  workflow_file:
    type: File
    doc: FragPipe workflow configuration file
    sbg:fileTypes: "WORKFLOW"
    
  manifest_file:
    type: File
    doc: FragPipe manifest file specifying mzML file paths
    sbg:fileTypes: "FP-MANIFEST"
    
  # mzML files from Cavatica platform
  mzml_files:
    type: File[]
    doc: Array of mzML files from Cavatica project
    sbg:fileTypes: "MZML"

outputs:
  # FragPipe outputs
  results_directory:
    type: Directory
    outputSource: run_fragpipe/results_directory
    doc: FragPipe output directory containing all results
    
  combined_protein:
    type: File?
    outputSource: run_fragpipe/combined_protein
    doc: Combined protein quantification results
    
  combined_peptide:
    type: File?
    outputSource: run_fragpipe/combined_peptide
    doc: Combined peptide quantification results
    
  combined_ion:
    type: File?
    outputSource: run_fragpipe/combined_ion
    doc: Combined ion quantification results
    
  log_file:
    type: File?
    outputSource: run_fragpipe/log_file
    doc: FragPipe execution log file

steps:
  # Step 1: Add decoys and contaminants to FASTA
  prepare_database:
    run: tools/philosopher-database.cwl
    in:
      query_fasta: query_fasta
      uniprot_canonical_fasta: uniprot_canonical_fasta
    out: [fasta_with_decoys]
    hints:
      sbg:x: 0
      sbg:y: 0
    
  # Step 2: Filter canonical peptides
  filter_canonical:
    run: tools/filter-canonical-peptides.cwl
    in:
      query_fasta: query_fasta
      fasta_with_decoys: prepare_database/fasta_with_decoys
    out: [filtered_fasta, gene_symbols]
    hints:
      sbg:x: 200
      sbg:y: 0
    
  # Step 3: Run FragPipe headless
  run_fragpipe:
    run: tools/fragpipe-headless.cwl
    in:
      filtered_fasta: filter_canonical/filtered_fasta
      workflow_file: workflow_file
      manifest_file: manifest_file
      mzml_files: mzml_files
    out: [results_directory, combined_protein, combined_peptide, combined_ion, log_file]
    hints:
      sbg:x: 400
      sbg:y: 0

$namespaces:
  sbg: https://sevenbridges.com

hints:
  sbg:maxNumberOfParallelInstances: 1

sbg:projectName: FragPipe Proteomics Analysis
sbg:categories:
  - Proteomics
  - Mass Spectrometry
  - Quantification
sbg:toolkit: FragPipe
sbg:toolkitVersion: "23.1"
