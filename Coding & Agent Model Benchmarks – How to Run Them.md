# Coding & Agent Model Benchmarks – How to Run Them

Oct 24, 2026 · @vk

Start with Aider Polyglot, then Terminal-Bench, SWE-bench Verified (50 tasks) and BFCL to compare Qwen3.8 27B (Q4) with Qwen3.8 Flash Next Coder on one RTX 3090. Run one model at a time with identical settings; the relative gap matters more than matching official scores.

## 1. Code generation (single problems)

| Benchmark | Measures | Notes |
| --- | --- | --- |
| HumanEval / MBPP | Small Python functions | Saturated (90%+); mostly historical |
| LiveCodeBench | Competitive-programming problems, refreshed over time against contamination | Current standard; Qwen3.8 27B \~90% (official) |

**How to run LiveCodeBench:** clone `github.com/LiveCodeBench/LiveCodeBench` and run its `lcb_runner` against the OpenAI-compatible endpoint on the newest problem window. Time: a few hours. Difficulty: easy.

## 2. Code editing: Aider Polyglot

Aider Polyglot is 225 hard Exercism exercises in C++, Go, Java, JavaScript, Python and Rust; the model edits code and tests decide pass/fail. Time: 4–10 h per model. Difficulty: easy — start here.

**Setup (once)** — from the [aider benchmark README](https://raw.githubusercontent.com/Aider-AI/aider/main/benchmark/README.md):

```bash
cd /mnt/fast
git clone https://github.com/Aider-AI/aider.git && cd aider
mkdir tmp.benchmarks
git clone https://github.com/Aider-AI/polyglot-benchmark tmp.benchmarks/polyglot-benchmark
./benchmark/docker_build.sh
```

In `benchmark/docker.sh`, add `--network host -e OPENAI_API_BASE -e OPENAI_API_KEY` to the `docker run` line so the container reaches the local server.

**Run** (llama-server with Qwen 27B running):

```bash
export OPENAI_API_BASE=http://127.0.0.1:8080/v1 OPENAI_API_KEY=aikeytake
./benchmark/docker.sh
# inside the container:
pip install -e .[dev]
./benchmark/benchmark.py qwen27b-q4 --model openai/qwen3.8-27b --edit-format whole \
  --threads 1 --exercises-dir polyglot-benchmark
```

Repeat with Strata running (`flashnext-coder`, key `local`). Add `--num-tests 20` for a trial run.

**Results** (outside the container): `./benchmark/benchmark.py --stats tmp.benchmarks/<run-folder>`, then compare `pass_rate_2` (solved within 2 tries).

## 3. Real-world software engineering

| Benchmark | Measures | Reference scores |
| --- | --- | --- |
| SWE-bench Verified | 500 human-checked GitHub issues (Python); agent edits the repo, hidden tests run | Flash Next Coder 79.2% ([ISTA-DASLab](https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-Coder-GGUF)) |
| SWE-bench Pro | Harder, multi-language, contamination-resistant | Qwen3.8 27B 61.7%, Flash Next 62.5% ([BenchLM](https://benchlm.ai/md/compare/qwen3-8-27b-vs-qwen3-8-flash-next.md)) |
| SWE-bench Multilingual | Same idea across languages | Flash Next 81% |
| NL2Repo / DeepSWE | Building whole repos, very long tasks | DeepSWE: 27B 42.2% vs Flash Next 58.7% |

Run SWE-bench Verified locally with mini-SWE-agent on a 50-task subset. Time: 6–12 h per model; needs 100+ GB disk for Docker images. Difficulty: medium.

**Install:** `pip install mini-swe-agent swebench` (in a venv).

**Point it at the server** — `registry.json`:

```json
{"qwen3.8-27b": {"max_tokens": 32768, "input_cost_per_token": 0, "output_cost_per_token": 0,
  "litellm_provider": "openai", "mode": "chat"}}
```

In mini-swe-agent's `config/extra/swebench.yaml` (format from the [mini-coder model card](https://huggingface.co/ricdomolm/mini-coder-1.7b)):

```yaml
model:
  model_name: "openai/qwen3.8-27b"
  model_kwargs:
    api_base: "http://127.0.0.1:8080/v1"
    api_key: "aikeytake"
```

**Generate patches:**

```bash
LITELLM_MODEL_REGISTRY_PATH=registry.json mini-extra swebench \
  --subset verified --split test --slice 0:50 --workers 1 --output runs/qwen27b
```

**Evaluate** (result = % resolved; repeat on the same 50 tasks for Flash Next):

```bash
python -m swebench.harness.run_evaluation --dataset_name princeton-nlp/SWE-bench_Verified \
  --predictions_path runs/qwen27b/preds.json --max_workers 4 --run_id qwen27b
```

Check `mini-extra swebench --help` if a flag name differs in your version.

## 4. Terminal and agent workflows: Terminal-Bench

Terminal-Bench 2.x tests real tasks in a Linux terminal (build, debug, configure, data work) and is the closest match to day-to-day use with Pi. Reference: Qwen3.8 27B scores 73.0% on TB 2.1.

**How to run:** Terminal-Bench uses the Harbor framework. Install Harbor, then run its Terminus agent against the local endpoint, roughly `harbor run -d terminal-bench@2.x -a terminus-2 -m openai/<model>` with the base URL pointing to the server. Check the exact syntax on tbench.ai. Time: several hours, in Docker. Difficulty: medium.

## 5. Tool use and function calling

| Benchmark | Measures | How to run | Time | Fully local? |
| --- | --- | --- | --- | --- |
| BFCL (Berkeley Function Calling Leaderboard) | Correct function names and arguments: single, parallel, multi-turn calls | `pip install bfcl-eval`, then generate and evaluate against an OpenAI-compatible model entry | 1–3 h | Yes |
| τ²-bench (tau-bench) | Multi-turn customer-service agents (airline, retail, telecom) following policies with tools and a simulated user | Clone `sierra-research/tau2-bench`; via litellm, point the agent at `openai/<model>` with your base URL | Several hours | No — the user simulator usually needs an API model |
| Toolathlon | Long multi-tool workflows across real apps | Heavier setup | Long | Partly |

BFCL is the quickest way to check tool-calling reliability, which is where looping agents usually break.

## 6. Computer and web agents

OSWorld (real desktop apps), WebArena (web tasks) and GAIA (general assistant tasks with web, files and tools) need VMs and browsers to set up. Skip them unless building that kind of agent.

## Recommended plan: 27B vs Flash Next

| Priority | Benchmark | Why |
| --- | --- | --- |
| 1 | Aider Polyglot | Easiest real coding benchmark, quick comparison |
| 2 | Terminal-Bench | Closest to the Pi workflow |
| 3 | SWE-bench Verified (50 tasks) | Real repository issues, industry standard |
| 4 | BFCL | Tool-calling reliability |

**Rules for a fair test**

- Benchmark one model at a time: both servers use port 8080 and the GPU.
- Same settings for both: context (e.g. 64K), thinking level, each model's recommended sampling, `--parallel 1`.
- Run each benchmark 2+ times; record time and tokens, not only scores.
- Run long jobs overnight in `tmux`; install Docker first (`sudo apt install -y docker.io`).
- Official scores are upper bounds (max reasoning effort, tuned harnesses); the relative gap between the two models is what counts.

## Sources

- [Aider benchmark README](https://raw.githubusercontent.com/Aider-AI/aider/main/benchmark/README.md)
- [mini-coder model card (mini-SWE-agent with a local server)](https://huggingface.co/ricdomolm/mini-coder-1.7b)
- [ISTA-DASLab – Qwen3.8 Flash Next GSQ-RCO Coder](https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-Coder-GGUF)
- [BenchLM – Qwen3.8 27B vs Flash Next](https://benchlm.ai/md/compare/qwen3-8-27b-vs-qwen3-8-flash-next.md)
