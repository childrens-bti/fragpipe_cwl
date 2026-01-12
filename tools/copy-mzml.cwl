cwlVersion: v1.2
class: CommandLineTool

label: Copy mzML Files
doc: |
  Copy uncompressed mzML files from a source directory to a local output directory.
  Also handles annotation files and generates FragPipe manifest.

baseCommand: [bash, /opt/scripts/copy-mzml.sh]

requirements:
  InlineJavascriptRequirement: {}
  DockerRequirement:
    dockerPull: "pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest"
  InitialWorkDirRequirement:
    listing:
      - writable: true
        entry: mzml_files
        entryname: mzml_files

inputs:
  mzml_source_dir:
    type: Directory
    doc: Directory containing uncompressed mzML files
    inputBinding:
      position: 1

  run_subset:
    type: string
    doc: Literal "true"/"false" string controlling subset processing
    inputBinding:
      position: 2

  manifest_file:
    type: File
    doc: Manifest file listing mzML base names to process (required)
    inputBinding:
      position: 3

outputs:
  mzml_directory:
    type: Directory
    outputBinding:
      glob: "mzml_files"
    doc: Directory containing copied mzML files

  mzml_file_list:
    type: File
    outputBinding:
      glob: "mzml_files.txt"
    doc: Text file listing all mzML file paths

  mzml_manifest:
    type: File
    outputBinding:
      glob: "mzml_manifest.fp-manifest"
    doc: FragPipe manifest file for mzML files
