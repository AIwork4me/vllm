#!/bin/bash
# 00_capture_env.sh — Phase 1 machine capture (already executed; artifacts in ../environment/)
set -euo pipefail
OUT=/workspace/validation-54706-e2e/environment
mkdir -p "$OUT"
{ date -u; uname -a; cat /etc/os-release; lscpu; free -h; df -h; } > "$OUT/00-system.txt" 2>&1
rocminfo > "$OUT/00-rocminfo.txt" 2>&1 || true
rocm-smi > "$OUT/00-rocm-smi.txt" 2>&1 || true
hipcc --version > "$OUT/00-hipcc.txt" 2>&1 || true
export PATH=/opt/venv/bin:$PATH
{ python --version; pip --version; git --version; } > "$OUT/01-python.txt" 2>&1
python - > "$OUT/01-torch.txt" 2>&1 <<'PY'
import torch
print("torch =", torch.__version__)
print("torch.version.hip =", torch.version.hip)
print("torch.version.cuda =", torch.version.cuda)
print("device count =", torch.cuda.device_count())
print("device 0 =", torch.cuda.get_device_name(0))
print("capability =", torch.cuda.get_device_capability(0))
PY
env | sort | grep -Ei 'ROCM|HIP|HSA|CUDA|PYTORCH|VLLM|HF_|TRANSFORMERS|TOKENIZERS|OMP|NCCL|RCCL' > "$OUT/02-envvars.txt" || true
{ pgrep -af 'vllm|EngineCore' || true; rocm-smi --showmeminfo vram; } > "$OUT/03-resources.txt" 2>&1
