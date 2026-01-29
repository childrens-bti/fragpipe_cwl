cwlVersion: v1.2
class: CommandLineTool

label: Filter Canonical Peptides
doc: |
  Remove canonical peptides annotated to genes in the custom FASTA file.
  This mirrors the filtering logic in run_fragpipe.sh by collecting all genes
  represented by custom peptide entries and dropping matching canonical records.

baseCommand: [bash, /opt/scripts/filter-canonical-peptides.sh]

requirements:
  InlineJavascriptRequirement: {}
  DockerRequirement:
    dockerPull: "pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:latest"
  InitialWorkDirRequirement:
    listing:
      - $(inputs.query_fasta)
      - $(inputs.fasta_with_decoys)

inputs:
  query_fasta:
    type: File
    doc: Original custom FASTA file (used to extract gene symbols)
    inputBinding:
      position: 1

  fasta_with_decoys:
    type: File
    doc: FASTA file with decoys and contaminants added
    inputBinding:
      position: 2

outputs:
  filtered_fasta:
    type: File
    outputBinding:
      glob: "decoys-contam-custom-canonical.fasta"
    doc: FASTA file with canonical peptides filtered out

  gene_symbols:
    type: File
    outputBinding:
      glob: "gene_symbols.txt"
    doc: List of gene symbols extracted from custom FASTA
