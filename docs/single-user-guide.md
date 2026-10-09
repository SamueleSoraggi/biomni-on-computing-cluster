# Biomni on GenomeDK: Single-User Guide

Oct 9, 2026 · Samuele

## What you get

Biomni is installed on GenomeDK as one container image with its full software environment (Python, R/Bioconductor and about 20 command-line bioinformatics tools) plus its 11 GB data lake. You never install anything yourself; every command below runs Biomni on a compute node.

There are three ways to use it. Pick by how you want to work:

| Way | Best for | Command |
| --- | --- | --- |
| Web interface | Chatting with Biomni, exploring, uploading files | `biomni-start` |
| Interactive Python | Scripting the agent, mixing it with your own code | `srun ... biomni-exec python` |
| Batch job | Long or repeated tasks that run unattended | `sbatch jobs/run_task.sbatch "..."` |

In this guide `$BIOMNI` stands for the install folder, `/faststorage/project/HDSSandbox/Workspaces/samuele/biomni`.

## Setup (once)

1. **Access.** You need to be a member of the GenomeDK project that holds the install (`HDSSandbox`), since its folder is closed to non-members. Your jobs are billed to the SLURM account named in `$BIOMNI/course.conf` (`ACCOUNT=hdssandbox`); change that line if you work under another project.
2. **Choose the AI model and add the commands to your PATH:**

   ```
   $BIOMNI/bin/biomni-setup
   source ~/.bashrc
   ```

   Type `1`–`3` and paste your own API key (Anthropic, OpenAI or Google), or type `0` to use a free open model that you run yourself (see *Your own free open model* below). This writes `~/.biomni.env`, readable only by you.

Advanced: `~/.biomni.env` is a plain `KEY=value` file. You can edit it directly to set any variable Biomni reads, for example `BIOMNI_LLM=claude-sonnet-4-5`, `BIOMNI_TIMEOUT_SECONDS=1200` or a second provider's key. Keys exported in your shell are passed into the container too.

## Web interface

On the login node, run `biomni-start`. It submits a session job (4 CPUs, 16 GB, 4 hours on `short`, set in `course.conf`), waits until Biomni is up, then prints:

- the compute node and port, for example `cn-1040:40217`;
- an `ssh -N -L 7860:<node>:<port> you@login.genome.au.dk` command to run in a terminal **on your laptop**, or the `<node>:<port>` to forward in VS Code's PORTS tab;
- a password for this session.

Open `http://localhost:7860` and log in with your cluster username and that password. Files Biomni creates go to `~/biomni_work/session_<date>_<time>/`. Run `biomni-start` again to see the details of the running session, and `biomni-stop` to end it. The interface is protected by the per-session password rather than Biomni's built-in access code, which is public.

## Interactive Python

`biomni-exec` runs any command inside the Biomni image with your settings applied: your API key or the free model, the data lake path, and the thread count matching your allocated CPUs. Ask for a compute node and start Python there:

```
srun -A hdssandbox -p short -c 4 --mem 32G -t 2:00:00 --pty $BIOMNI/bin/biomni-exec python
```

```python
from biomni.agent import A1
agent = A1()   # model and data path come from your settings
log, answer = agent.go("Predict ADMET properties for CC(C)CC1=CC=C(C=C1)C(C)C(=O)O")
```

The agent writes its files to your current folder, so `cd` into a project folder first. The same wrapper runs your own scripts (`biomni-exec python analysis.py`), R (`biomni-exec Rscript ...`), the bundled tools (`biomni-exec samtools ...`) or a shell inside the image (`biomni-exec bash`).

## Batch jobs

For tasks that run unattended, submit one job per task from the folder where you want the results:

```
sbatch -A hdssandbox $BIOMNI/jobs/run_task.sbatch "Plan a CRISPR screen to identify genes that regulate T cell exhaustion"
sbatch -A hdssandbox $BIOMNI/jobs/run_task.sbatch --prompt-file task.txt --llm claude-sonnet-4-5
```

Each job writes `biomni-<jobid>.log` and a folder `biomni_run_<jobid>/` with `answer.md` (final answer), `log.json` (every step), `prompt.txt` and any files the agent made. The default request is 8 CPUs, 64 GB and 8 hours on `normal`; override with `sbatch -c`, `--mem` or `-t`.

For GPU tools (scvi-tools, cellpose, torch models) add `-p gpu-l40s --gres=gpu:1`; `biomni-exec` turns on GPU access automatically when a GPU is allocated.

## Your own free open model

Instead of a paid API key you can run an open model on a GPU yourself. Use **gpt-oss-120b**: in tests on 2026-10-09 it solved both a simple coding task and a data-lake task correctly, while smaller open models (gpt-oss-20b, qwen3-30b) skipped running code or invented results.

```
cd $BIOMNI
bin/biomni-model list                                # what is available and downloaded
bin/biomni-model start gpt-oss-120b 8                # 8 hours on one H200 GPU
bin/biomni-model start gpt-oss-120b 2 gpu-short 2    # or 2 hours on two L40S GPUs (usually free)
bin/biomni-model status
bin/biomni-model stop                                # free the GPU when you are done
```

gpt-oss-120b is already downloaded; other models are fetched once with `bin/biomni-model download <name>`. Starting takes 3–10 minutes once a GPU is free. Then choose option `0` in `biomni-setup` (or put `BIOMNI_COURSE_MODEL=1` in `~/.biomni.env`); every way of using Biomni above then uses your model. Your prompts and data stay on GenomeDK.

The server is shared with members of the project folder that can read `models/.server_key`, so stop it when you finish. If it is stopped or restarted, end and restart any running Biomni session (`biomni-stop`, `biomni-start`).

## Settings and troubleshooting

`biomni-exec` reads these environment variables; set them in your shell or in `~/.biomni.env`:

| Variable | Default | Effect |
| --- | --- | --- |
| `BIOMNI_LLM` | set by `biomni-setup` | Model name, e.g. `claude-sonnet-4-5`, `gpt-4o`, `gemini-2.5-pro`. |
| `BIOMNI_DATA_PATH` | `$BIOMNI/data` | Folder holding `biomni_data/data_lake`. |
| `BIOMNI_TIMEOUT_SECONDS` | `600` | Time limit for each piece of code the agent runs. |
| `BIOMNI_BIND` | none | Extra folders to make visible inside the image, comma-separated (`/faststorage` and your home are always visible). |
| `BIOMNI_GPU` | auto | `1` forces GPU access, `0` disables it. |
| `BIOMNI_SIF` | `$BIOMNI/biomni.sif` | Use a different image. |

Web-session resources (`CPUS`, `MEM`, `TIME`, `PARTITION`) and the SLURM `ACCOUNT` are in `$BIOMNI/course.conf`.

| Problem | Fix |
| --- | --- |
| `Invalid account or account/partition combination` | Set `ACCOUNT` in `course.conf`, or `-A` in `srun`/`sbatch`, to a project you belong to. |
| An agent task fails with an authentication or credit error | Check the key in `~/.biomni.env`, or run `biomni-setup` again. |
| `The free course model is not running right now` | Start it with `bin/biomni-model start <name>`. |
| A tool or package is missing | Biomni usually installs Python and R packages itself (into `~/.local/biomni-py311` and `~/R/biomni-library`); otherwise ask the maintainer to add it to the image. |
| `pip` packages you installed elsewhere interfere | They cannot: the image ignores your normal `~/.local`. Delete `~/.local/biomni-py311` to reset Biomni's own extras. |
