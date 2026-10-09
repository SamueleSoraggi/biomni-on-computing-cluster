#!/bin/bash
#SBATCH --job-name=biomni
#SBATCH --partition=normal
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=08:00:00
#SBATCH --output=biomni-%j.log
## For GPU tools (scvi-tools, cellpose, torch models) use instead:
##   #SBATCH --partition=gpu-l40s
##   #SBATCH --gres=gpu:1
#
# Run one Biomni task in batch.
#   sbatch -A <account> jobs/run_task.sbatch "Predict ADMET properties for CC(C)CC1=CC=C(C=C1)C(C)C(=O)O"
#   sbatch -A <account> jobs/run_task.sbatch --prompt-file my_task.txt --llm claude-sonnet-4-5
# Needs an LLM key in the environment or in ~/.biomni.env (see README).
# Log: ./biomni-<jobid>.log. Results: ./biomni_run_<jobid>/{answer.md,log.json,prompt.txt,<files the agent wrote>}
set -euo pipefail
# Install dir = parent of jobs/ (sbatch runs a spooled copy, so ask SLURM where the script lives)
REPO=$(dirname "$(dirname "$(scontrol show job "$SLURM_JOB_ID" | grep -oP 'Command=\K\S+')")")
cd "$SLURM_SUBMIT_DIR"
"$REPO/bin/biomni-exec" python "$REPO/scripts/run_task.py" "$@"
