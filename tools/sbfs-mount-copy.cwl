cwlVersion: v1.2
class: CommandLineTool

label: SBFS Mount and Copy mzML Files
doc: |
  Mount a Cavatica project using SBFS, copy mzML files to temporary directory,
  and unzip them. This tool is for LOCAL execution only where direct file
  access to Cavatica projects is needed.

baseCommand: [bash, /opt/impact_trial/scripts/sbfs-mount-copy.sh]

requirements:
  InlineJavascriptRequirement: {}
  DockerRequirement:
    dockerPull: "pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest"
  NetworkAccess:
    networkAccess: true
  InitialWorkDirRequirement:
    listing:
      - $(inputs.mount_script)

inputs:
  cohort:
    type: string
    doc: Cohort name - either 'hope' or 'cptac'
    inputBinding:
      position: 1

  run_subset:
    type: boolean
    default: false
    doc: If true, only process first experiment (01C prefix)
    inputBinding:
      position: 2

  mount_script:
    type: File
    doc: Shell script implementing SBFS mount and copy
    default:
      class: File
      location: ../scripts/sbfs-mount-copy.sh

outputs:
  mzml_directory:
    type: Directory
    outputBinding:
      glob: "/tmp/mzml_files"
    doc: Directory containing unzipped mzML files

  mzml_file_list:
    type: File
    outputBinding:
      glob: "mzml_files.txt"
    doc: Text file listing all mzML file paths

stdout: sbfs-mount.log
stderr: sbfs-mount.err
