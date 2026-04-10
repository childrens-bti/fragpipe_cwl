cwlVersion: v1.2
class: CommandLineTool

label: FragPipe PDV Batch Plotting
doc: |
  Generate PDV spectrum plots for peptides from a target peptide table.
  This tool parses psm.tsv files under a FragPipe results directory,
  extracts matching scan numbers, and runs PDV in batch mode.

baseCommand: [python3, /opt/scripts/fragpipe-pdv.py]

requirements:
  InlineJavascriptRequirement: {}
  DockerRequirement:
    dockerPull: "pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:fragpipe_v22"
  InitialWorkDirRequirement:
    listing:
      - entry: $(inputs.results_dir)
        entryname: $(inputs.results_dir.basename)
        writable: true
      - entry: $(inputs.mzml_directory)
        entryname: $(inputs.mzml_directory.basename)
      - $(inputs.target_peptide_table)

inputs:
  run_pdv:
    type: boolean?
    doc: Optional passthrough workflow flag used by parent step gating

  control_combined_peptide:
    type: File?
    doc: Optional passthrough control peptide file used by parent step gating

  results_dir:
    type: Directory
    doc: FragPipe results directory output by fragpipe-headless step
    inputBinding:
      position: 1

  mzml_directory:
    type: Directory
    doc: Directory containing mzML files used by FragPipe
    inputBinding:
      position: 2

  target_peptide_table:
    type: File
    doc: Filtered peptide table (typically *_combined_peptide_control_filtered.tsv)
    inputBinding:
      position: 3

  output_basename:
    type: string
    doc: Base name for output files
    inputBinding:
      position: 4

outputs:
  pdv_spectra_dir:
    type: Directory
    outputBinding:
      glob: "$(inputs.results_dir.basename)/$(inputs.output_basename)_pdv_spectra"
    doc: Directory containing PDV-generated spectrum plots and run summary
