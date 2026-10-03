#!/bin/bash
# run_gsm8k.sh — full GSM8K via lm-eval local-completions against the served model
# Usage: run_gsm8k.sh <arm> <outdir> [limit]
set -euo pipefail
ARM=$1
OUTDIR=$2
LIMIT=${3:-}
export PATH=/opt/venv/bin:$PATH
mkdir -p "$OUTDIR"
LIM_ARG=""
[ -n "$LIMIT" ] && LIM_ARG="--limit $LIMIT"

date -u +"start %Y-%m-%dT%H:%M:%SZ" | tee "$OUTDIR/timing.txt"
lm_eval \
  --model local-completions \
  --model_args model=/opt/models/gemma-3-27b-it-w4a16,base_url=http://127.0.0.1:8000/v1/completions,tokenizer_backend=huggingface,num_concurrent=8,max_retries=5 \
  --tasks gsm8k \
  --num_fewshot 5 \
  $LIM_ARG \
  --log_samples \
  --output_path "$OUTDIR" \
  2>&1 | tee "$OUTDIR/lm_eval_stdout.txt"
date -u +"end %Y-%m-%dT%H:%M:%SZ" | tee -a "$OUTDIR/timing.txt"
