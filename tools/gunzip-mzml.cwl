cwlVersion: v1.2
class: CommandLineTool

label: Gunzip mzML Files
doc: |
  Decompress gzipped mzML files from a mounted Cavatica directory
  to a local output directory. Also handles annotation files and 
  generates FragPipe manifest.

baseCommand: [bash, /opt/scripts/gunzip-mzml.sh]

requirements:
  InlineJavascriptRequirement: {}
  DockerRequirement:
    dockerPull: "pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:v1.2.0"
  InitialWorkDirRequirement:
    listing:
      - writable: true
        entry: input_files
        entryname: input_files

inputs:
  input_type:
    type: string?
    doc: Optional - input type from the workflow (not passed to script)

  skip_gunzip:
    type: boolean?
    default: false
    doc: Optional - for backward compatibility (not passed to script)

  input_source_dir:
    type: Directory
    doc: Mounted Cavatica directory with gzipped mzML files
    inputBinding:
      position: 1

  run_subset:
    type: string
    doc: Literal "true"/"false" string controlling subset processing
    inputBinding:
      position: 2

  subset_pattern:
    type: string
    doc: Pattern to match in directory path when run_subset is true
    inputBinding:
      position: 3

  manifest_file:
    type: File
    doc: Manifest file listing mzML base names to process (required)
    inputBinding:
      position: 4

outputs:
  input_directory:
    type: Directory
    outputBinding:
      glob: "input_files"
    doc: Directory containing unzipped mzML files

  input_file_list:
    type: File
    outputBinding:
      glob: "input_files.txt"
    doc: Text file listing all unzipped mzML file paths

  input_manifest:
    type: File
    outputBinding:
      glob: "input_manifest.fp-manifest"
    doc: FragPipe manifest file for decompressed mzML files
