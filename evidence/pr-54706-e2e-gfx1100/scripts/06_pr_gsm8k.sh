#!/bin/bash
# 06_pr_gsm8k.sh — Phase 14: PR-arm GSM8K smoke + full (identical methodology to 03)
set -euo pipefail
bash /workspace/validation-54706-e2e/scripts/run_gsm8k.sh pr \
  /workspace/validation-54706-e2e/patched/lm_eval/smoke 20
setsid nohup bash /workspace/validation-54706-e2e/scripts/run_gsm8k.sh pr \
  /workspace/validation-54706-e2e/patched/lm_eval/full \
  > /workspace/validation-54706-e2e/patched/lm_eval/full-runner.log 2>&1 < /dev/null &
echo "full run detached; monitor lm_eval_stdout.txt"
