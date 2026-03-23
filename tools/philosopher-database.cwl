cwlVersion: v1.2
class: CommandLineTool

label: Philosopher Database Preparation
doc: |
  Add decoys and contaminants to a custom FASTA file using Philosopher.
  This tool initializes a Philosopher workspace, adds decoys from a canonical
  UniProt FASTA and contaminants to the query FASTA file.

baseCommand: [bash, /opt/scripts/philosopher-database.sh]

requirements:
  InlineJavascriptRequirement: {}
  DockerRequirement:
    dockerPull: "pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:fragpipe_v24"
  InitialWorkDirRequirement:
    listing:
      - $(inputs.query_fasta)
      - $(inputs.uniprot_canonical_fasta)

inputs:
  query_fasta:
    type: File
    doc: Custom FASTA file containing query peptides
    inputBinding:
      position: 1

  uniprot_canonical_fasta:
    type: File
    doc: UniProt canonical FASTA file (gzipped), e.g., UP000005640_9606.fasta.gz
    inputBinding:
      position: 2

outputs:
  fasta_with_decoys:
    type: File
    outputBinding:
      glob: "decoys-contam-custom.fasta.fas"
    doc: FASTA file with added decoys and contaminants
