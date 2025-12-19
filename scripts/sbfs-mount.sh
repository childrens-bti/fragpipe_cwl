#!/bin/bash
set -e
set -o pipefail

# Usage: sbfs-mount.sh <project> [mountpoint]
# Example: sbfs-mount.sh harenżaj/hope-proteomics data/cavatica-data

PROJECT="$1"
# Resolve mountpoint to absolute path so Docker binds correctly
MOUNTPOINT="${2:-data/cavatica-data}"
MOUNTPOINT="$(readlink -f "$MOUNTPOINT")"

if [ -z "$PROJECT" ]; then
  echo "Usage: $0 <project> [mountpoint]" >&2
  exit 2
fi

SBFS_LOG_DIR="${SBFS_LOG_DIR:-$(pwd)/sbfs-logs}"
export SBFS_LOG_DIR
export HOME="${HOME:-$(pwd)/sbfs-home}"
mkdir -p "$SBFS_LOG_DIR" "$HOME" "$MOUNTPOINT"

echo "Mounting Cavatica project '$PROJECT' to '$MOUNTPOINT'..."
echo "Note: ensure /etc/fuse.conf has user_allow_other enabled if using --allow-other."
if ! sbfs mount --profile default --project "$PROJECT" --allow-other "$MOUNTPOINT"; then
  echo "ERROR: sbfs mount failed. Check FUSE permissions (user_allow_other) and credentials." >&2
  exit 1
fi

echo "Waiting for mountpoint to become active..."
until mountpoint -q "$MOUNTPOINT"; do
  sleep 1
done

echo "Mount is active at $MOUNTPOINT"
rm -r "$SBFS_LOG_DIR" "$HOME"
