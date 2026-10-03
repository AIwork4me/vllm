#!/bin/bash
# vllm_cli.sh — launcher for the vLLM CLI on the gfx1100 validation box.
#
# Environment quirks handled here, IDENTICALLY for both A/B arms (see README):
#   1. LD_LIBRARY_PATH must put the venv torch's ROCm 7.14 userspace
#      (_rocm_sdk_core/lib) ahead of system /opt/rocm 7.2.1 libs; otherwise
#      vllm/env_override.py's early libtorch_cpu.so preload wins a soname race
#      for libamdhip64.so.7/libhsa-runtime64.so.1 and torch fails to import
#      (undefined symbol hsa_amd_vmem_export_fabric_handle, version ROCR_1).
#   2. amdsmi cannot co-exist with an initialized ROCm runtime in one process
#      on this box, so vLLM's builtin ROCm platform *detection* fails. The
#      out-of-tree plugin vllm-gfx1100-rocm-platform-plugin (pip-installed in
#      the shared venv, identical for both arms) selects the same
#      vllm.platforms.rocm.RocmPlatform class when FORCE_ROCM_PLATFORM=1.
#   3. cd to a neutral cwd: running from /root (or a vLLM checkout) shadows
#      the editable-installed vllm package with a namespace package.
export PATH=/opt/venv/bin:$PATH
V=/opt/venv/lib/python3.12/site-packages/_rocm_sdk_core/lib
export LD_LIBRARY_PATH=$V:/opt/rocm/lib:/usr/local/lib
export FORCE_ROCM_PLATFORM=1
export VLLM_LOGGING_LEVEL=INFO
cd /workspace
exec python -c "import torch; import sys; sys.argv=['vllm']+sys.argv[1:]; from vllm.entrypoints.cli.main import main; main()" "$@"
