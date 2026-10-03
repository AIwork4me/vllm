# Environment — gfx1100 validation box (captured 2026-10-03 UTC)

Raw captures live alongside this file (`00-system.txt`, `01-python.txt`, `02-envvars.txt`,
`03-resources.txt`, `04-git-provenance.txt`, `model-hashes.txt`, `model-download*.log`).
This page summarizes what matters for the A/B.

## Hardware

- GPU: **1x AMD Radeon Pro W7900D — gfx1100** (`rocminfo`: `amdgcn-amd-amdhsa--gfx1100`,
  chip 0x744b; torch capability (11, 0)), 48 GB VRAM (51,522,830,336 B), device count 1
- CPU: AMD EPYC 9334 32-core (128 hw threads), 503 GB RAM
- Disk: 2.1 TB free on / ; /workspace is a 98 GB loop mount (~19 GB free at capture)

## Software stack (identical for both arms)

| Component | Version |
|---|---|
| OS / kernel | Ubuntu, Linux 6.8.0-79-generic |
| ROCk kernel module | 6.16.13 |
| HIP runtime | 1.21 (rocminfo header) |
| torch | 2.13.0+rocm7.14.0 (torch.version.hip = 7.14.60850, venv `_rocm_sdk_core`) |
| hipcc toolchain | HIP 7.14.60850 on ROCm 7.2.1 LLVM (`/opt/rocm-7.2.1`, clang 22.0.0git) — pre-existing machine mix |
| Python / venv | 3.12.3, /opt/venv |
| compressed-tensors | 0.17.0 (pinned by both arms' requirements/common.txt) |
| lm-eval | 0.4.13 (+ tenacity 9.1.4) |
| vLLM BASE arm | 0.30.1rc1.dev538+g28c57456d.rocm721 (editable, /root/wt-e2e-baseline) |
| vLLM PR arm | 0.30.1rc1.dev541+g16ce8ac88.rocm721 (editable, /root/wt-e2e-pr) |
| platform plugin | vllm-gfx1100-rocm-platform-plugin 0.1.0 (env-gated detection aid, see INCIDENTS.md #3) |

## Model

- Local path: `/opt/models/gemma-3-27b-it-w4a16` (28 GB, 4/4 safetensors shards finalized)
- Source: `hf.co/RedHatAI/gemma-3-27b-it-quantized.w4a16` @ revision `2b537554d6c6f6368945e8df4e5fb7bbbb5d56c9`
  (recorded in every shard's HF download `.metadata`; download command captured live in checkpoint-1-2 report)
- Architecture: Gemma3ForConditionalGeneration (VLM); text hidden_size 5376; max_position_embeddings 131072
- Quantization: compressed-tensors, pack-quantized, W4A16, **symmetric int4 (uint4b8)**, group_size 128,
  strategy group, observer mse, actorder weight, targets Linear
- Full sha256 set (shards + config + tokenizer + recipe + index) in `model-hashes.txt`;
  independently recomputed and confirmed complete/untouched by two verifiers

## Box quirks handled identically for both arms

1. LD_LIBRARY_PATH must put venv ROCm 7.14 libs before system 7.2.1 (INCIDENTS.md #2)
2. amdsmi unusable in-process with ROCm runtime → FORCE_ROCM_PLATFORM=1 detection plugin (INCIDENTS.md #3)
3. Neutral cwd for all python/vllm invocations (INCIDENTS.md #5)
4. Zombie `[vllm-omni]` reapers hold no resources; excluded from process counts

## GPU state hygiene

- Pre-experiment: VRAM used 28 MB (idle), no live vLLM processes
- Between arms: baseline server killed cleanly, VRAM returned to 28 MB before PR arm start
  (see baseline/final-gpu-state.txt, patched/final-gpu-state.txt)
