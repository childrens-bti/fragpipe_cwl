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
        entry: mzml_files
        entryname: mzml_files

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
    type: int?
    doc: Number of parallel msconvert processes (default uses runtime.cores)
    inputBinding:
      position: 5
      valueFrom: $(self || Math.min(runtime.cores || 12, 4))

hints:
  ResourceRequirement:
    coresMin: 4
    ramMin: 131072

outputs:
  mzml_directory:
    type: Directory
    outputBinding:
      glob: "mzml_files"
    doc: Directory containing converted mzML files

  mzml_file_list:
    type: File
    outputBinding:
      glob: "mzml_files.txt"
    doc: Text file listing all converted mzML file paths

  mzml_manifest:
    type: File
    outputBinding:
      glob: "mzml_manifest.fp-manifest"
    doc: FragPipe manifest file for converted mzML files
