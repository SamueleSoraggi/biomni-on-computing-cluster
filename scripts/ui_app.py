"""Biomni web UI for one student session (started by jobs/ui_session.sbatch).

Biomni's own UI protection is a hard-coded public access code, which does not protect a
session from other users on a shared compute node. Instead, wrap gradio's launch() to require
the student's username plus a random per-session password (read from a file only they can read).
"""

import os

import gradio as gr

user = os.environ["USER"]
with open(os.environ["BIOMNI_UI_PASSWORD_FILE"]) as fh:
    password = fh.read().strip()
port = int(os.environ["GRADIO_SERVER_PORT"])

_launch = gr.Blocks.launch


def _launch_with_login(self, *args, **kwargs):
    kwargs.update(
        auth=(user, password),
        auth_message="Log in with your cluster username and the session password shown by biomni-start.",
        server_name="0.0.0.0",  # reached through an SSH tunnel via the login node
        server_port=port,
        share=False,  # never create a public gradio.live link
    )
    return _launch(self, *args, **kwargs)


gr.Blocks.launch = _launch_with_login

from biomni.agent import A1  # noqa: E402

agent = A1(path=os.environ["BIOMNI_DATA_PATH"])
agent.launch_gradio_demo(require_verification=False)
