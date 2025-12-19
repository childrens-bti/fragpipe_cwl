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

  mzml_directory:
    type: Directory
    doc: Directory containing decompressed mzML files

outputs:
  combined_protein:
    type: File?
    outputBinding:
      glob: "protein.tsv"
    doc: Combined protein quantification results

  combined_peptide:
    type: File?
    outputBinding:
      glob: "peptide.tsv"
    doc: Combined peptide quantification results

  combined_ion:
    type: File?
    outputBinding:
      glob: "ion.tsv"
    doc: Combined ion quantification results

  log_file:
    type: File?
    outputBinding:
      glob: "log_*.txt"
    doc: FragPipe execution log file
