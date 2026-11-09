cwlVersion: v1.2
class: CommandLineTool

label: MSConvert - Convert .raw files to mzML
doc: |
  Convert Thermo Fisher .raw files to mzML format using msconvert.
  Uses ProteoWizard msconvert via wine.

baseCommand: [bash, /opt/scripts/msconvert-raw.sh]

requirements:
  InlineJavascriptRequirement: {}
  DockerRequirement:
    dockerPull: "pgc-images.sbgenomics.com/childrens-bti/pwiz-msconvert:latest"
  InitialWorkDirRequirement:
    listing:
      - writable: true
        entry: input_files
        entryname: input_files

inputs:
  input_type:
    type: string?
    doc: Optional - detected input type from detect-input-type tool (not passed to script)

  raw_source_dir:
    type: Directory
    doc: Directory containing .raw files
    inputBinding:
      position: 1
  
  run_subset:
    type: string
    doc: Literal "true"/"false" string controlling subset processing
    inputBinding:
      position: 2

  subset_pattern:
    type: string
    doc: Pattern to match for basename when run_subset is true
    inputBinding:
      position: 3

  manifest_file:
    type: File
    doc: Manifest file listing raw file base names to process (required)
    inputBinding:
      position: 4

  num_cores:
    type: int
    default: 8
    doc: Number of parallel msconvert processes
    inputBinding:
      position: 5

hints:
  ResourceRequirement:
    coresMin: 12
    ramMin: 131072

outputs:
  input_directory:
    type: Directory
    outputBinding:
      glob: "input_files"
    doc: Directory containing converted mzML files

  input_file_list:
    type: File
    outputBinding:
      glob: "input_files.txt"
    doc: Text file listing all converted mzML file paths

  input_manifest:
    type: File
    outputBinding:
      glob: "input_manifest.fp-manifest"
    doc: FragPipe manifest file for converted mzML files
