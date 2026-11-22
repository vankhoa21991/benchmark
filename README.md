# Coding & Agent Model Benchmarks — workspace

Setup for comparing **Qwen3.8 27B (Q4)** vs **Qwen3.8 Flash Next Coder** on one RTX 3090,
per `Coding & Agent Model Benchmarks – How to Run Them.md`.

Both models are served by `llama-server` (llama.cpp, built in `/mnt/fast/Strata`) on
`http://127.0.0.1:8080/v1`. **Run one model at a time** — one port, one GPU.

## Layout

| Path | What | Status |
| --- | --- | --- |
| `aider/` | Aider Polyglot (225 Exercism exercises in 6 languages) | clone + `docker.sh` patched; image built (see below) |
| `aider/tmp.benchmarks/polyglot-benchmark/` | the exercises | cloned |
| `swebench/` | SWE-bench Verified (50-task subset) via mini-swe-agent | `.venv` ready, config in `config/extra/swebench.yaml` |
| `bfcl/` | BFCL (Berkeley Function Calling Leaderboard) | `.venv` ready |
| `terminal-bench/` | Terminal-Bench 2.x via Harbor | `.venv` ready (harbor 0.24.0) |
| `LiveCodeBench/` | LiveCodeBench (`lcb_runner`) | `.venv` ready (CPU-torch, no vllm) |
| `.install-logs/` | pip install logs | — |

## One-time fixes still needed (require sudo)

```bash
# Docker access (needed by Aider Polyglot + SWE-bench + Terminal-Bench):
sudo usermod -aG docker $USER    # then log out/in (or: newgrp docker)

# tmux for long overnight runs:
sudo apt install -y tmux
```

## 1. Aider Polyglot (priority 1)

Build the image once (after Docker access is fixed):

```bash
cd aider
./benchmark/docker_build.sh
```

`benchmark/docker.sh` is already patched with `--network host -e OPENAI_API_BASE -e OPENAI_API_KEY`.

Run (Qwen 27B on the server):

```bash
cd aider
export OPENAI_API_BASE=http://127.0.0.1:8080/v1 OPENAI_API_KEY=aikeytake
./benchmark/docker.sh
# inside the container:
pip install -e .[dev]
./benchmark/benchmark.py qwen27b-q4 --model openai/qwen3.8-27b --edit-format whole \
  --threads 1 --exercises-dir polyglot-benchmark
# trial first: add --num-tests 20
```

Flash Next: same, but restart the server with the Flash Next model, key `local`,
run name `flashnext-coder`.

Results (outside the container): `./benchmark/benchmark.py --stats tmp.benchmarks/<run-folder>`
→ compare `pass_rate_2`.

## 2. SWE-bench Verified, 50 tasks (priority 3)

```bash
cd swebench
source .venv/bin/activate

# The model config is passed explicitly: `-c` replaces the default config, so the stock
# swebench.yaml must be listed first and the local-model overrides merged on top.
CFG="-c swebench.yaml -c config/extra/swebench.yaml"

# Qwen 27B (config/extra/swebench.yaml currently points at openai/qwen3.8-27b, key aikeytake).
# Use a fresh --output dir per run (reruns into an existing dir resume/skip finished tasks):
LITELLM_MODEL_REGISTRY_PATH=registry.json mini-extra swebench $CFG \
  --subset verified --split test --slice 0:50 --workers 1 --output runs/qwen27b

# Flash Next: edit config/extra/swebench.yaml (model_name openai/flashnext-coder, api_key local), then:
LITELLM_MODEL_REGISTRY_PATH=registry.json mini-extra swebench $CFG \
  --subset verified --split test --slice 0:50 --workers 1 --output runs/flashnext

# Evaluate (% resolved), per model:
python -m swebench.harness.run_evaluation --dataset_name princeton-nlp/SWE-bench_Verified \
  --predictions_path runs/qwen27b/preds.json --max_workers 4 --run_id qwen27b
```

Needs Docker (instance containers) and 100+ GB of disk for images.

## 3. Terminal-Bench 2.x (priority 2)

Harbor is installed in `terminal-bench/.venv`. Run its Terminus agent against the local
endpoint (check exact current syntax at tbench.ai / `harbor --help`):

```bash
source terminal-bench/.venv/bin/activate
harbor run -d terminal-bench@2.x -a terminus-2 -m openai/<model> \
  --url http://127.0.0.1:8080/v1   # + api key per model
```

Reference: Qwen3.8 27B ≈ 73.0% on TB 2.1.

## 4. BFCL (priority 4)

Local models are registered in the installed bfcl-eval by `bfcl/setup.sh` (already run;
re-run after upgrading bfcl-eval). Both entries use `OpenAICompletionsHandler`, which
reads `OPENAI_BASE_URL` / `OPENAI_API_KEY`.

```bash
cd bfcl
source .venv/bin/activate
export OPENAI_API_KEY=aikeytake OPENAI_BASE_URL=http://127.0.0.1:8080/v1
bfcl generate --model qwen3.8-27b --test-category all
bfcl evaluate --model qwen3.8-27b
# Flash Next: --model qwen3.8-flashnext-coder (server restarted, key local)
```

## 5. LiveCodeBench

Both local models are already registered in `LiveCodeBench/lcb_runner/lm_styles.py`
(`qwen3.8-27b`, `qwen3.8-flashnext-coder`, OpenAIChat style → OpenAIRunner).

```bash
cd LiveCodeBench
source .venv/bin/activate
# OpenAIRunner reads OPENAI_KEY and the SDK default OPENAI_BASE_URL:
export OPENAI_KEY=aikeytake OPENAI_BASE_URL=http://127.0.0.1:8080/v1
python -m lcb_runner.runner.main \
  --model qwen3.8-27b \
  --scenario codegeneration \
  --start_date 2025-06-01 --end_date 2025-10-01 \
  --evaluate \
  --max_tokens 32768 --n 1 --temperature 0.6 --multiprocess 8
# Same sampling flags for both models. Flash Next: --model qwen3.8-flashnext-coder (server restarted with that model, key local)
```

The venv uses `--no-deps` install + light deps + **CPU torch** (torch is only touched in
the local-vllm code path). No vllm/CUDA needed.

## Fair-test rules

- One model at a time; identical settings: context (64K), thinking level, each model's
  recommended sampling, `--workers/--threads 1`.
- Run each benchmark 2+ times; record time and tokens, not only scores.
- Long jobs overnight in `tmux`.
- Official scores are upper bounds; the relative gap is what counts.

## Repo contents

Only my own files are tracked here. `aider/`, `LiveCodeBench/`, venvs and run outputs are not.
Clone those upstream and apply the local changes:

```bash
git clone https://github.com/Aider-AI/aider aider && (cd aider && git apply ../patches/aider-docker.patch)
git clone https://github.com/LiveCodeBench/LiveCodeBench && (cd LiveCodeBench && git apply ../patches/livecodebench-lm_styles.patch)
```
