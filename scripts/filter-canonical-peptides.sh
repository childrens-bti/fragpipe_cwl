#!/usr/bin/env bash
set -euo pipefail

query_fasta="$1"
fasta_with_decoys="$2"

# splice event genes
awk '
/^>/ {
  line = substr($0, 2)  # drop leading ">"
  if (match(line, /_([^_]+)_phase[0-9]+$/, a)) {
    print a[1]
  }
}' "$query_fasta" | sort -u > splice_event_genes.txt

# snv genes
awk -F '|' '{print $3}' "$query_fasta" \
| grep -v '^$' \
| grep -v '\^ENS' \
| sort \
| uniq > snv_genes.txt

# arriba fusion genes
if grep -q '^>arriba' "$query_fasta"; then
  grep '^>arriba' "$query_fasta" \
  | awk -F'|' '{print $3; print $6}' \
  | grep -v '^$' \
  | grep -v ',' \
  | grep -v 'ENSP' \
  | grep -v "^chr" \
  | grep -v '\^ENS' \
  | grep -v 'NP_' \
  | sort \
  | uniq > arriba_fusion_genes.txt
else
  : > arriba_fusion_genes.txt
fi

# star fusion genes
if grep -q '^>star' "$query_fasta"; then
  grep '^>star' "$query_fasta" \
  | awk -F'|' '{gsub(/\^.*/,"",$2); gsub(/\^.*/,"",$5); print $2; print $5}' \
  | grep -v '-' \
  | sort \
  | uniq > star_fusion_genes.txt
else
  : > star_fusion_genes.txt
fi

# merge gene lists
cat splice_event_genes.txt snv_genes.txt arriba_fusion_genes.txt star_fusion_genes.txt \
| sort \
| uniq > genes_to_rm.txt

# append "GN" to match gene designation in canonical fasta
sed 's/^/GN=/' genes_to_rm.txt > gn_genes_to_rm.txt

# preserve non-prefixed list for reference/output
cp genes_to_rm.txt gene_symbols.txt

# remove genes from custom + canonical fasta
awk 'BEGIN{
         while ((getline k < "gn_genes_to_rm.txt") > 0) {
             if (k != "") a[k]=1
         }
     }
     /^>/{
         keep=1
         for (g in a) {
             if (index($0,g)) {keep=0; break}
         }
     }
     keep' "$fasta_with_decoys" > decoys-contam-custom-canonical.fasta
