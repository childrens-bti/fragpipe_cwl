cwlVersion: v1.2
class: CommandLineTool

label: Class-specific FDR
doc: |
  Score custom (non-canonical) database entries against their own decoys rather
  than against the whole proteome.

  A custom entry -- a translated splice junction, variant or novel ORF -- is
  usually supported by exactly one peptide. A global protein-level FDR treats
  that as a single-hit protein and discards it, so a search can complete and
  report nothing from the class it was built to find.

  Reads PERCOLATOR output, not psm.tsv: Philosopher has already applied a global
  FDR and dropped decoys by the time psm.tsv exists. Requires
  percolator.keep-tsv-files=true in the workflow.

baseCommand: [python3, /opt/scripts/class-specific-fdr.py]

requirements:
  InlineJavascriptRequirement: {}
  DockerRequirement:
    dockerPull: "pgc-images.sbgenomics.com/childrens-bti/fragpipe_cwl:v1.2.0"

inputs:
  results_dir:
    type: Directory
    doc: FragPipe results directory containing *_percolator_{target,decoy}_psms.tsv
    inputBinding:
      prefix: --results_dir

  class_prefix:
    type: string
    doc: |
      Accession prefix identifying the custom class, e.g. "tr|TEJ". Decoys carry
      the decoy prefix in front of it (rev_tr|TEJ...), so the match is a
      substring test, not a startswith.
    inputBinding:
      prefix: --class_prefix

  fdr:
    type: float?
    default: 0.01
    doc: FDR threshold applied within each class
    inputBinding:
      prefix: --fdr

  output_basename:
    type: string
    inputBinding:
      prefix: --out_basename

outputs:
  class_fdr_psms:
    type: File
    doc: |
      PSMs passing their own class's FDR, with a class_qvalue column. Note the
      floor: with n target PSMs in a class the lowest achievable q is 1/n, so a
      small class cannot be certified at a tight threshold however good its
      scores. The tool warns when that applies.
    outputBinding:
      glob: "$(inputs.output_basename)_class_fdr_psms.tsv"
