#!/bin/bash
#SBATCH --job-name=biomni-datalake
#SBATCH --partition=short
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=logs/datalake-%j.log
#
# One-time download of the Biomni data lake into $BIOMNI_DATA_PATH (default <repo>/data).
#   sbatch -A <account> jobs/download_datalake.sbatch
set -euo pipefail
REPO=$(cd "${SLURM_SUBMIT_DIR:-.}" && pwd)
"$REPO/bin/biomni-exec" python "$REPO/scripts/download_datalake.py"
