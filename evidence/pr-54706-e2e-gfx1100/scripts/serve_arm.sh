#!/bin/bash
# serve_arm.sh — activate one A/B arm (editable install re-point) and serve the model
# Usage: serve_arm.sh <baseline|pr> <logdir>
# NOTE: the editable re-point takes ~7 min (build-backend pass, incremental compile).
set -euo pipefail
ARM=$1
LOGDIR=$2
export PATH=/opt/venv/bin:$PATH
export VLLM_LOGGING_LEVEL=INFO

case "$ARM" in
  baseline) WT=/root/wt-e2e-baseline; TMPD=/root/tmp-baseline ;;
  pr)       WT=/root/wt-e2e-pr;       TMPD=/root/tmp-pr ;;
  *) echo "bad arm"; exit 1 ;;
esac

# ensure no stale server is running before switching arms
pkill -f "vllm serve" 2>/dev/null || true
pkill -f "from vllm.entrypoints.cli" 2>/dev/null || true
sleep 5

# Re-point editable install to this worktree (incremental rebuild of the .so in place)
export PYTORCH_ROCM_ARCH=gfx1100
export MAX_JOBS=64
export TRITON_KERNELS_SRC_DIR=/opt/venv/lib/python3.12/site-packages/triton_kernels
export RUSTUP_TOOLCHAIN=stable-x86_64-unknown-linux-gnu
export TMPDIR=$TMPD
mkdir -p "$TMPDIR"
cd "$WT"
pip install -e . --no-deps --no-build-isolation

# Record install identity (must show this worktree + its .so)
mkdir -p "$LOGDIR"
V=/opt/venv/lib/python3.12/site-packages/_rocm_sdk_core/lib
LD_LIBRARY_PATH=$V:/opt/rocm/lib:/usr/local/lib FORCE_ROCM_PLATFORM=1 \
python - > "$LOGDIR/install-identity.txt" <<PY
import torch, vllm, vllm._rocm_C, subprocess
print("vllm:", vllm.__version__)
print("vllm file:", vllm.__file__)
print("worktree HEAD:", subprocess.check_output(["git","-C","$WT","rev-parse","HEAD"]).decode().strip())
print("git status dirty entries:", subprocess.check_output(["git","-C","$WT","status","--porcelain"]).decode().strip().count("\n"))
print("_rocm_C.abi3.so md5:", subprocess.check_output(["md5sum","$WT/vllm/_rocm_C.abi3.so"]).decode().strip())
from vllm.platforms import current_platform
print("platform:", type(current_platform).__name__)
print("has gptq_gemm_rdna3:", hasattr(torch.ops._rocm_C, "gptq_gemm_rdna3"))
PY
cat "$LOGDIR/install-identity.txt"
grep -q "$WT" "$LOGDIR/install-identity.txt" || { echo "ARM SWITCH FAILED"; exit 1; }

# Serve (frozen flags — see results/experiment-config.txt); launcher sets env fixes
cd /root   # neutral cwd (avoid cwd shadowing vllm imports)
nohup /workspace/validation-54706-e2e/scripts/vllm_cli.sh serve /opt/models/gemma-3-27b-it-w4a16 \
  --tensor-parallel-size 1 \
  --dtype bfloat16 \
  --gpu-memory-utilization 0.92 \
  --max-model-len 8192 \
  --host 127.0.0.1 --port 8000 \
  > "$LOGDIR/server.log" 2>&1 &
echo $! > "$LOGDIR/server.pid"

# Wait for readiness
for i in $(seq 1 120); do
  if curl -s http://127.0.0.1:8000/v1/models 2>/dev/null | grep -q gemma; then
    echo "server ready (~$((i*10))s)"; break
  fi
  if ! kill -0 $(cat "$LOGDIR/server.pid") 2>/dev/null; then
    echo "SERVER DIED"; tail -40 "$LOGDIR/server.log"; exit 1
  fi
  sleep 10
done
curl -s http://127.0.0.1:8000/v1/models | head -c 400; echo
echo "=== routing evidence ==="
{ grep -aoE "Using [A-Za-z0-9]+LinearKernel[^ ]*" "$LOGDIR/server.log" | sort | uniq -c;
  grep -aiE "attention backend|Using .* backend" "$LOGDIR/server.log" | sort -u | head -5; } | tee "$LOGDIR/routing.txt"
