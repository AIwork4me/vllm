#!/bin/bash
# 01_build_baseline.sh — clean build of vLLM BASE arm (28c57456) for gfx1100
set -euo pipefail
export PATH=/opt/venv/bin:$PATH
export PYTORCH_ROCM_ARCH=gfx1100
export MAX_JOBS=64
export TRITON_KERNELS_SRC_DIR=/opt/venv/lib/python3.12/site-packages/triton_kernels
export RUSTUP_TOOLCHAIN=stable-x86_64-unknown-linux-gnu
export TMPDIR=/root/tmp-baseline
mkdir -p "$TMPDIR"
WT=/root/wt-e2e-baseline
cd "$WT"
git status --porcelain | wc -l   # must be 0
git rev-parse HEAD                # expect 28c57456db9220fbdde6041a20b97bebd141259b
# fully clean build state (no stale objects)
rm -rf build vllm/*.so vllm/_C* 2>/dev/null || true
pip install -e . --no-deps --no-build-isolation
python - <<'PY'
import torch, vllm
print("torch:", torch.__version__)
print("hip:", torch.version.hip)
print("vllm:", vllm.__version__)
print("vllm file:", vllm.__file__)
print("device:", torch.cuda.get_device_name(0))
assert hasattr(torch.ops._rocm_C, "gptq_gemm_rdna3"), "gptq_gemm_rdna3 op missing!"
print("torch.ops._rocm_C.gptq_gemm_rdna3: PRESENT")
PY
md5sum "$WT"/vllm/_rocm_C.abi3.so
