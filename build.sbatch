#!/bin/bash
#SBATCH --job-name=biomni-build
#SBATCH --partition=normal
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output=logs/build-%j.log
#
# Builds biomni.sif unprivileged (--fakeroot) on a compute node.
# Usage:  sbatch -A <account> build.sbatch                 # pinned default ref from biomni.def
#         sbatch -A <account> build.sbatch main            # or any branch/tag/commit
set -euo pipefail

SRC_DIR=${SLURM_SUBMIT_DIR:-$(pwd)}
REF=${1:-}
OUT=$SRC_DIR/biomni.sif

# Build on node-local disk: the unpacked sandbox is ~40 GB and many small files
# (slow and hard on BeeGFS). Only the finished SIF is copied back.
WORK=${TMPDIR:-/tmp}/biomni-build-$SLURM_JOB_ID
mkdir -p "$WORK"/{tmp,cache}
trap 'rm -rf "$WORK"' EXIT
export APPTAINER_TMPDIR=$WORK/tmp
export APPTAINER_CACHEDIR=$WORK/cache

echo "Building on $(hostname) in $WORK, ref=${REF:-<default>}"
args=(--fakeroot --force --notest)
[ -n "$REF" ] && args+=(--build-arg "BIOMNI_REF=$REF")
apptainer build "${args[@]}" --mksquashfs-args "-processors ${SLURM_CPUS_PER_TASK:-4}" \
    "$WORK/biomni.sif" "$SRC_DIR/biomni.def"

mv "$WORK/biomni.sif" "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
ls -lh "$OUT"

# Smoke tests (%test section) run separately so a failing check does not discard the build
apptainer test "$OUT" && echo "SMOKE TESTS PASSED" || echo "SMOKE TESTS FAILED (image kept)"
