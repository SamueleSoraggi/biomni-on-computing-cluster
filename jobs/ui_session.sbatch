#!/bin/bash
#SBATCH --job-name=biomni-ui
# Submitted by bin/biomni-start (which sets account, resources, output and these variables):
#   BIOMNI_REPO          install directory
#   BIOMNI_SESSION_DIR   this session's working directory (agent output lands here)
#   BIOMNI_STATE_DIR     where to publish node/port for biomni-start
set -euo pipefail
umask 077
cd "$BIOMNI_SESSION_DIR"

# Free port on this node, published for biomni-start to read
export GRADIO_SERVER_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1])')
printf 'NODE=%s\nPORT=%s\nJOBID=%s\nSESSION_DIR=%s\n' \
    "$(hostname -s)" "$GRADIO_SERVER_PORT" "$SLURM_JOB_ID" "$BIOMNI_SESSION_DIR" > "$BIOMNI_STATE_DIR/session.$SLURM_JOB_ID"

export BIOMNI_UI_PASSWORD_FILE=$BIOMNI_STATE_DIR/password.$SLURM_JOB_ID
# gradio checks itself over localhost; never send that through an HTTP proxy
export NO_PROXY=localhost,127.0.0.1 no_proxy=localhost,127.0.0.1
exec "$BIOMNI_REPO/bin/biomni-exec" python -u "$BIOMNI_REPO/scripts/ui_app.py"
