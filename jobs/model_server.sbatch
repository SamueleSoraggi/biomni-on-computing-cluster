#!/bin/bash
#SBATCH --job-name=biomni-model
# Shared open-model server (vLLM, OpenAI-compatible API) for the course.
# Submitted by `bin/biomni-model start`, which sets partition/GPUs/time and these variables:
#   BIOMNI_REPO   install directory
#   MODEL_NAME    name from models/catalog.tsv (= the name students' Biomni asks for)
#   VLLM_EXTRA    extra vLLM arguments from the catalog
set -euo pipefail
MODELS=$BIOMNI_REPO/models
umask 027   # endpoint + key readable by the course group only

PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1])')
NODE=$(hostname -s)

# vLLM reads the key from the environment (not the command line, which other users can see in ps)
export APPTAINERENV_VLLM_API_KEY=$(cat "$MODELS/.server_key")
export APPTAINERENV_HF_HUB_OFFLINE=1
export APPTAINERENV_VLLM_CACHE_ROOT=$TMPDIR/vllm-cache
export APPTAINERENV_HF_HOME=$TMPDIR/hf
# Several GPUs: direct GPU-to-GPU transfers hang inside the container on these nodes, so
# route NCCL through host memory instead (slightly slower, reliable)
if [ "$(tr ',' '\n' <<<"${CUDA_VISIBLE_DEVICES:-0}" | wc -l)" -gt 1 ]; then
    export APPTAINERENV_NCCL_P2P_DISABLE=1 APPTAINERENV_NCCL_IB_DISABLE=1
fi

# Published only once the server answers (below); removed again when the job ends
rm -f "$MODELS/endpoint"
trap 'rm -f "$MODELS/endpoint"' EXIT

# shellcheck disable=SC2086
apptainer exec --nv --cleanenv --bind "$MODELS" --bind "$TMPDIR" "$(ls -v "$MODELS"/vllm-*.sif | tail -1)" \
    vllm serve "$MODELS/$MODEL_NAME" --served-model-name "$MODEL_NAME" \
        --host 0.0.0.0 --port "$PORT" $VLLM_EXTRA &
SERVER=$!

until curl --noproxy "*" -sf -o /dev/null -H "Authorization: Bearer $APPTAINERENV_VLLM_API_KEY" "http://localhost:$PORT/v1/models"; do
    kill -0 $SERVER 2>/dev/null || { echo "vLLM exited before it was ready"; exit 1; }
    sleep 10
done
printf 'URL=http://%s:%s/v1\nMODEL=%s\nJOBID=%s\n' "$NODE" "$PORT" "$MODEL_NAME" "$SLURM_JOB_ID" > "$MODELS/endpoint.tmp"
mv "$MODELS/endpoint.tmp" "$MODELS/endpoint"
echo "MODEL SERVER READY: $MODEL_NAME at http://$NODE:$PORT/v1"
wait $SERVER
