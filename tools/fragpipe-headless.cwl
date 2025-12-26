cwlVersion: v1.2
class: CommandLineTool

label: FragPipe Headless Execution
doc: |
  Run FragPipe in headless mode for proteomics analysis.
  This tool executes FragPipe with a specified workflow, manifest file,
  and processed FASTA database.

baseCommand: [bash, /opt/impact_trial/scripts/fragpipe-headless.sh]

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

  results_dir:
    type: string
    doc: Output directory for FragPipe results (relative to runtime working dir)
    inputBinding:
      position: 4

  mzml_directory:
    type: Directory
    doc: Directory containing decompressed mzML files

outputs:
  results_directory:
    type: Directory
    outputBinding:
      glob: $(inputs.results_dir)
    doc: FragPipe results directory

  combined_protein:
    type: File?
    outputBinding:
      glob: $(inputs.results_dir)/combined_protein.tsv
    doc: Combined protein quantification results

  combined_peptide:
    type: File?
    outputBinding:
      glob: $(inputs.results_dir)/combined_peptide.tsv
    doc: Combined peptide quantification results

  combined_modified_peptide:
    type: File?
    outputBinding:
      glob: $(inputs.results_dir)/combined_modified_peptide.tsv
    doc: Combined modified peptide quantification results

  combined_ion:
    type: File?
    outputBinding:
      glob: $(inputs.results_dir)/combined_ion.tsv
    doc: Combined ion quantification results

  tmt_report:
    type: Directory?
    outputBinding:
      glob: $(inputs.results_dir)/tmt-report
    doc: TMT reporter ion quantification results

  workflow_file_out:
    type: File?
    outputBinding:
      glob: $(inputs.results_dir)/fragpipe.workflow
    doc: FragPipe workflow configuration used

  fragger_params:
    type: File?
    outputBinding:
      glob: $(inputs.results_dir)/fragger.params
    doc: MSFragger parameter file

  tmt_integrator_conf:
    type: File?
    outputBinding:
      glob: $(inputs.results_dir)/tmt-integrator-conf.yml
    doc: TMT-Integrator configuration file

  experiment_annotation:
    type: File?
    outputBinding:
      glob: $(inputs.results_dir)/experiment_annotation.tsv
    doc: Experiment annotation file

  sdrf_file:
    type: File?
    outputBinding:
      glob: $(inputs.results_dir)/sdrf.tsv
    doc: SDRF metadata file

  manifest_file_out:
    type: File?
    outputBinding:
      glob: $(inputs.results_dir)/fragpipe-files.fp-manifest
    doc: FragPipe manifest file used

  log_file:
    type: File?
    outputBinding:
      glob: $(inputs.results_dir)/log_*.txt
    doc: FragPipe execution log file