#!/bin/bash
# Registers the two local llama.cpp models in the installed bfcl-eval package.
# Idempotent. Re-run after `pip install -U bfcl-eval`.
# Usage: ./bfcl/setup.sh
set -e
cd "$(dirname "$0")"
CFG="$(.venv/bin/python -c 'import bfcl_eval.constants.model_config as m; print(m.__file__)')"
if grep -q "BENCHMARK_LOCAL_MODELS" "$CFG"; then
  echo "Already registered in $CFG"
  exit 0
fi
cat >> "$CFG" <<'EOF'

# --- BENCHMARK_LOCAL_MODELS: local llama.cpp via OpenAI-compatible endpoint ---
# Endpoint from env: OPENAI_BASE_URL=http://127.0.0.1:8080/v1, OPENAI_API_KEY=<key>
MODEL_CONFIG_MAPPING["qwen3.8-27b"] = ModelConfig(
    model_name="qwen3.8-27b",
    display_name="Qwen3.8-27B (Q4, llama.cpp)",
    url="local",
    org="local",
    license="local",
    model_handler=OpenAICompletionsHandler,
    input_price=None,
    output_price=None,
    is_fc_model=False,
    underscore_to_dot=False,
)
MODEL_CONFIG_MAPPING["qwen3.8-flashnext-coder"] = ModelConfig(
    model_name="qwen3.8-flashnext-coder",
    display_name="Qwen3.8-Flash-Next-Coder (llama.cpp)",
    url="local",
    org="local",
    license="local",
    model_handler=OpenAICompletionsHandler,
    input_price=None,
    output_price=None,
    is_fc_model=False,
    underscore_to_dot=False,
)
EOF
echo "Registered local models in $CFG"
