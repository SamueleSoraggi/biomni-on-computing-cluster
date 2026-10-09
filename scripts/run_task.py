"""Run one Biomni A1 task non-interactively (for sbatch).

    biomni-exec python scripts/run_task.py "Plan a CRISPR screen ..."
    biomni-exec python scripts/run_task.py --prompt-file task.txt --out results/run1

Model/provider come from --llm/--source or BIOMNI_LLM / BIOMNI_SOURCE; data from BIOMNI_DATA_PATH.
The agent executes code in the current working directory, so run each task in its own directory.
"""

import argparse
import json
import os
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument("prompt", nargs="?")
parser.add_argument("--prompt-file")
parser.add_argument("--llm", default=None, help="e.g. claude-sonnet-4-5 (default: BIOMNI_LLM or biomni default)")
parser.add_argument("--source", default=None, help="Anthropic, OpenAI, AzureOpenAI, Gemini, Bedrock, Groq, Ollama, Custom")
parser.add_argument("--out", default=None, help="output dir (default: biomni_run_<SLURM_JOB_ID or timestamp>)")
parser.add_argument("--no-datalake", action="store_true", help="skip data lake check/download")
args = parser.parse_args()

if args.prompt_file:
    with open(args.prompt_file) as fh:
        prompt = fh.read()
else:
    prompt = args.prompt
if not prompt:
    parser.error("give a prompt or --prompt-file")

run_id = os.environ.get("SLURM_JOB_ID") or time.strftime("%Y%m%d-%H%M%S")
out = os.path.abspath(args.out or f"biomni_run_{run_id}")
os.makedirs(out, exist_ok=True)
data_path = os.path.abspath(os.environ.get("BIOMNI_DATA_PATH", "./data"))
os.chdir(out)  # files the agent writes land here

from biomni.agent import A1  # noqa: E402

kwargs = {"path": data_path}
if args.llm:
    kwargs["llm"] = args.llm
if args.source:
    kwargs["source"] = args.source
if args.no_datalake:
    kwargs["expected_data_lake_files"] = []

agent = A1(**kwargs)
t0 = time.time()
log, answer = agent.go(prompt)

with open("prompt.txt", "w") as fh:
    fh.write(prompt)
with open("answer.md", "w") as fh:
    fh.write(str(answer))
with open("log.json", "w") as fh:
    json.dump([str(step) for step in log], fh, indent=1)
print(f"\nDone in {time.time() - t0:.0f}s -> {out}", file=sys.stderr)
