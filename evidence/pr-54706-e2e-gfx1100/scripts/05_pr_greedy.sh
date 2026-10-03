#!/bin/bash
# 05_pr_greedy.sh — Phase 13: PR-arm fixed-input greedy repeatability (same protocol as 02)
set -euo pipefail
mkdir -p /workspace/validation-54706-e2e/patched/determinism
cd /workspace
PATH=/opt/venv/bin:$PATH python3 /workspace/validation-54706-e2e/scripts/greedy_probe.py \
  pr /workspace/validation-54706-e2e/patched/determinism
