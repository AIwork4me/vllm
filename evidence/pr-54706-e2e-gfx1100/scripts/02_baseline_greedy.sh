#!/bin/bash
# 02_baseline_greedy.sh — Phase 7: baseline fixed-input greedy repeatability
# Prereq: baseline server running on :8000 (see serve_arm.sh baseline ...)
set -euo pipefail
mkdir -p /workspace/validation-54706-e2e/baseline/determinism
cd /workspace
PATH=/opt/venv/bin:$PATH python3 /workspace/validation-54706-e2e/scripts/greedy_probe.py \
  baseline /workspace/validation-54706-e2e/baseline/determinism
