#!/bin/bash
# 03_baseline_gsm8k.sh — Phase 9 smoke + Phase 10 full GSM8K for the baseline arm
# Prereq: baseline server running on :8000 (see serve_arm.sh baseline ...)
set -euo pipefail
# smoke (~20 examples; sanity only, NOT the published score)
bash /workspace/validation-54706-e2e/scripts/run_gsm8k.sh baseline \
  /workspace/validation-54706-e2e/baseline/lm_eval/smoke 20
# full test set (no --limit)
setsid nohup bash /workspace/validation-54706-e2e/scripts/run_gsm8k.sh baseline \
  /workspace/validation-54706-e2e/baseline/lm_eval/full \
  > /workspace/validation-54706-e2e/baseline/lm_eval/full-runner.log 2>&1 < /dev/null &
echo "full run detached; monitor lm_eval_stdout.txt"
