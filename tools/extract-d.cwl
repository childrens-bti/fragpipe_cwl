cwlVersion: v1.2
class: CommandLineTool

label: Extract Bruker .d Archives
doc: |
  Extract Bruker timsTOF runs from <run>.d.zip, .d.tar, .d.tar.gz or .d.tgz archives in a
  source directory into a local output directory. Each archive must contain a single
  top-level <run>.d/ with analysis.tdf. MSFragger reads .d natively, so no conversion is
  done; extracting to a local directory also lets MSFragger write <run>.mzBIN and
  <run>_uncalibrated.mzML next to each .d. Also generates FragPipe manifest, keeping the data
  type (4th column) from the input manifest and defaulting to DDA.
  Requires the Bruker reader (ext/bruker/libtimsdata-2-21-0-4.so) in the image.

baseCommand: [bash, /opt/scripts/extract-d.sh]

requirements:
  InlineJavascriptRequirement: {}
  DockerRequirement:
    dockerPull: "pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:fragpipe_v22"
  InitialWorkDirRequirement:
    listing:
      - writable: true
        entry: mzml_files
        entryname: mzml_files

inputs:
  input_type:
    type: string?
    doc: Optional - input type from the workflow (not passed to script)

  mzml_source_dir:
    type: Directory
    doc: Directory containing Bruker .d.zip/.d.tar/.d.tar.gz/.d.tgz archives
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
    doc: Manifest file listing .d base names (without .d or archive extension) to process (required)
    inputBinding:
      position: 4

outputs:
  mzml_directory:
    type: Directory
    outputBinding:
      glob: "mzml_files"
    doc: Directory containing extracted .d directories

  mzml_file_list:
    type: File
    outputBinding:
      glob: "mzml_files.txt"
    doc: Text file listing all .d directory paths

  mzml_manifest:
    type: File
    outputBinding:
      glob: "mzml_manifest.fp-manifest"
    doc: FragPipe manifest file for .d directories
