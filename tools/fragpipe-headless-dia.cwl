cwlVersion: v1.2
class: CommandLineTool

label: FragPipe Headless DIA Execution
doc: |
  Run FragPipe in headless mode for DIA workflows.
  This tool executes FragPipe with a DIA workflow and captures DIA-NN outputs.

baseCommand: [bash, /opt/scripts/fragpipe-headless-dia.sh]

requirements:
  InlineJavascriptRequirement: {}
  DockerRequirement:
    dockerPull: "pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest"
  InplaceUpdateRequirement:
    inplaceUpdate: true
  EnvVarRequirement:
    envDef:
      HOME: $(runtime.outdir)
      XDG_CONFIG_HOME: $(runtime.outdir)/.config
      XDG_CACHE_HOME: $(runtime.outdir)/.cache
      JAVA_TOOL_OPTIONS: -Duser.home=$(runtime.outdir)

  InitialWorkDirRequirement:
    listing:
      - $(inputs.filtered_fasta)
      - $(inputs.workflow_file)
      - $(inputs.manifest_file)
      - entryname: $(inputs.mzml_directory.basename)
        writable: true
        entry: $(inputs.mzml_directory)

inputs:
  filtered_fasta:
    type: File
    doc: Processed FASTA file with decoys, contaminants, and filtered canonical peptides
    inputBinding:
      position: 1

  workflow_file:
    type: File
    doc: FragPipe workflow configuration file (.workflow)
    inputBinding:
      position: 2

  manifest_file:
    type: File
    doc: FragPipe manifest file specifying mzML file paths (.fp-manifest)
    inputBinding:
      position: 3

  output_basename:
    type: string
    doc: Base name for all output files (e.g., "IMPACT002-Run2-DIA")
    inputBinding:
      position: 4

  acquisition_mode:
    type: string?
    doc: Optional pass-through mode selector from workflow conditional logic

  mzml_directory:
    type: Directory
    doc: Directory containing decompressed mzML files

outputs:
  # Common metadata/config outputs
  workflow_file_out:
    type: File?
    outputBinding:
      glob: "results/$(inputs.output_basename)_fragpipe.workflow"
    doc: FragPipe workflow configuration used

  fragger_params:
    type: File?
    outputBinding:
      glob: "results/$(inputs.output_basename)_fragger.params"
    doc: MSFragger parameter file

  experiment_annotation:
    type: File?
    outputBinding:
      glob: "results/$(inputs.output_basename)_experiment_annotation.tsv"
    doc: Experiment annotation file

  sdrf_file:
    type: File?
    outputBinding:
      glob: "results/$(inputs.output_basename)_sdrf.tsv"
    doc: SDRF metadata file

  manifest_file_out:
    type: File?
    outputBinding:
      glob: "results/$(inputs.output_basename)_fragpipe-files.fp-manifest"
    doc: FragPipe manifest file used

  log_file:
    type: File?
    outputBinding:
      glob: "results/$(inputs.output_basename)_log*.txt"
    doc: FragPipe execution log file

  # DIA-specific outputs
  diann_report:
    type: File?
    outputBinding:
      glob: "results/diann-output/$(inputs.output_basename)_report.tsv"
    doc: DIA-NN main report table

  diann_pr_matrix:
    type: File?
    outputBinding:
      glob: "results/diann-output/$(inputs.output_basename)_report.pr_matrix.tsv"
    doc: DIA-NN precursor intensity matrix

  diann_pg_matrix:
    type: File?
    outputBinding:
      glob: "results/diann-output/$(inputs.output_basename)_report.pg_matrix.tsv"
    doc: DIA-NN protein group intensity matrix

  diann_stats:
    type: File?
    outputBinding:
      glob: "results/diann-output/$(inputs.output_basename)_report.stats.tsv"
    doc: DIA-NN run statistics

  diann_msstats:
    type: File?
    outputBinding:
      glob: "results/diann-output/$(inputs.output_basename)_MSstats.csv"
    doc: MSstats table converted from DIA-NN report

  peptide_tsv:
    type: File?
    outputBinding:
      glob: "results/$(inputs.output_basename)_peptide.tsv"
    doc: Philosopher peptide-level report

  protein_tsv:
    type: File?
    outputBinding:
      glob: "results/$(inputs.output_basename)_protein.tsv"
    doc: Philosopher protein-level report

