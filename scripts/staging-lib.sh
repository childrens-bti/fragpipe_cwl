# Shared helpers for the staging scripts (copy-mzml.sh, gunzip-mzml.sh,
# msconvert-raw.sh, extract-d.sh). Source it; do not execute it.
#
# Callers must set GROUP_BY_EXPERIMENT ("true"/"false") before using these.

# Fail unless every staged file sits exactly one directory below SOURCE_DIR
# (<source>/<plex>/<file>) when GROUP_BY_EXPERIMENT is true.
#
# The plex is taken from the first directory under SOURCE_DIR, so a flat layout
# (files directly in SOURCE_DIR) or a nested <cohort>/<plex>/ layout would give
# every plex the same experiment. TMT-Integrator would then treat all plexes as
# one, keep only the first annotation.txt, and still exit 0.
#
# Usage: check_plex_layout <SOURCE_DIR> <file>...
# <file> paths must start with <SOURCE_DIR> as given (e.g. find "$SOURCE_DIR" output).
check_plex_layout() {
  local src="${1%/}" f rel bad=()
  shift
  [[ "${GROUP_BY_EXPERIMENT:-false}" == "true" ]] || return 0
  for f in "$@"; do
    [[ -n "$f" ]] || continue
    rel="${f#"$src"/}"
    # rel must be exactly "<plex>/<file>": one slash, not unchanged by the strip
    if [[ "$rel" == "$f" || "$rel" != */* || "${rel#*/}" == */* ]]; then
      bad+=("$f")
    fi
  done
  if [[ ${#bad[@]} -gt 0 ]]; then
    echo "ERROR: group_by_experiment requires <input_source_dir>/<plex>/<file> layout;" >&2
    echo "  ${#bad[@]} file(s) are directly in $src or more than one level deep:" >&2
    printf '  %s\n' "${bad[@]}" >&2
    exit 5
  fi
}

# Resolve the FragPipe manifest "experiment" column (column 2).
# Files are staged into input_files/<plex>/, so with GROUP_BY_EXPERIMENT the plex
# is the directory holding the file and every fraction of a plex shares one
# experiment (required for a joint TMT search). Otherwise each file gets its own
# experiment, which is the historical behaviour.
#
# Usage: manifest_experiment <staged_path> <run_basename>
manifest_experiment() {
  if [[ "${GROUP_BY_EXPERIMENT:-false}" == "true" ]]; then
    basename "$(dirname "$1")"
  else
    printf '%s\n' "$2"
  fi
}
