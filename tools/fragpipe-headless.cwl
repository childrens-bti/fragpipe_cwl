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
  InitialWorkDirRequirement:
    listing:
      - $(inputs.filtered_fasta)
      - $(inputs.workflow_file)
      - $(inputs.manifest_file)
      - $(inputs.fragpipe_script)
      - entryname: mzml_files
        writable: true
        entry: |
          ${
            return inputs.mzml_files ? inputs.mzml_files : null;
          }

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

  mzml_files:
    type: File[]?
    doc: Optional array of mzML files (for Cavatica platform execution)

  fragpipe_script:
    type: File
    doc: Shell script implementing FragPipe headless execution
    default:
      class: File
      location: ../scripts/fragpipe-headless.sh

outputs:
  results_directory:
    type: Directory
    outputBinding:
      glob: "results"
    doc: FragPipe output directory containing all results

  combined_protein:
    type: File?
    outputBinding:
      glob: "results/combined_protein.tsv"
    doc: Combined protein quantification results

  combined_peptide:
    type: File?
    outputBinding:
      glob: "results/combined_peptide.tsv"
    doc: Combined peptide quantification results

  combined_ion:
    type: File?
    outputBinding:
      glob: "results/combined_ion.tsv"
    doc: Combined ion quantification results

  log_file:
    type: File?
    outputBinding:
      glob: "results/log_*.txt"
    doc: FragPipe execution log file

stdout: fragpipe.log
stderr: fragpipe.err
