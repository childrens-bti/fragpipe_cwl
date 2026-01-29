#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sbfs-mount.sh <project> [mountpoint] [--cleanup]
# Example:
#   sbfs-mount.sh harenzaj/hope-proteomics data/cavatica-data
#   sbfs-mount.sh harenzaj/hope-proteomics data/cavatica-data --cleanup

PROJECT="${1:-}"
MOUNTPOINT_REL="${2:-data/cavatica-data}"
CLEANUP="${3:-}"   # optional: --cleanup

if [[ -z "$PROJECT" ]]; then
  echo "Usage: $0 <project> [mountpoint] [--cleanup]" >&2
  exit 2
fi

# Resolve mountpoint to absolute path (helps with Docker binds)
MOUNTPOINT="$(readlink -f "$MOUNTPOINT_REL")"
REPO_ROOT="$(readlink -f "$(pwd)")"

# Keep sbfs scratch dirs separate from user's real HOME
SBFS_LOG_DIR="${SBFS_LOG_DIR:-$REPO_ROOT/.sbfs-logs}"
SBFS_HOME="${SBFS_HOME:-$REPO_ROOT/.sbfs-home}"


# Make sure cleanup targets are exactly what we think they are
safe_rm_rf() {
  local target="$1"
  [[ -n "$target" ]] || die "Refusing to rm empty path"
  [[ "$target" == "$REPO_ROOT/"* ]] || die "Refusing to rm outside repo: $target"
  [[ "$target" != "$REPO_ROOT" ]] || die "Refusing to rm repo root"
  rm -rf -- "$target"
}

mkdir -p "$SBFS_LOG_DIR" "$SBFS_HOME" "$MOUNTPOINT"

# Ensure SBFS uses SBFS_HOME rather than real HOME
export SBFS_LOG_DIR
export HOME="$SBFS_HOME"

# If already mounted, do nothing
if mountpoint -q "$MOUNTPOINT"; then
  echo "Mountpoint already active at $MOUNTPOINT"
  exit 0
fi

echo "Mounting Cavatica project '$PROJECT' to '$MOUNTPOINT'..."
echo "Note: ensure /etc/fuse.conf has user_allow_other enabled if using --allow-other."

if ! sbfs --profile default mount --project "$PROJECT" --allow-other "$MOUNTPOINT"; then
  die "sbfs mount failed. Check FUSE permissions (user_allow_other) and credentials."
fi

echo "Waiting for mountpoint to become active..."
for _ in {1..60}; do
  if mountpoint -q "$MOUNTPOINT"; then
    echo "Mount is active at $MOUNTPOINT"
    break
  fi
  sleep 1
done

mountpoint -q "$MOUNTPOINT" || die "Timed out waiting for mountpoint to become active: $MOUNTPOINT"

# Optional cleanup of sbfs scratch dirs (safe)
if [[ "$CLEANUP" == "--cleanup" ]]; then
  echo "Cleaning up SBFS temp dirs: $SBFS_LOG_DIR $SBFS_HOME"
  safe_rm_rf "$SBFS_LOG_DIR"
  safe_rm_rf "$SBFS_HOME"
fi
echo "Mount completed successfully."
