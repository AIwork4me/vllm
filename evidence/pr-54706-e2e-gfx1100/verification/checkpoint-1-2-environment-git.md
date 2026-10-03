# Independent Verification Report — PR #54706 A/B Validation
**Agent:** independent verifier (no prior claims trusted; all evidence re-collected)
**Date:** Sat Oct 3, 2026 (~01:20 UTC)
**Scope:** Checkpoint 1 (Environment), Checkpoint 2 (Git provenance + model-choice rationale)

---

## VERDICT CHECKPOINT 1 — Environment: **PASS WITH NOTES**

All hard requirements independently re-verified; notes are observational, none blocking.

### 1. GPU = real gfx1100 — VERIFIED
```
$ rocminfo | grep -E 'gfx1100|Marketing Name' | head -6
  Marketing Name:          AMD EPYC 9334 32-Core Processor
  Marketing Name:          AMD EPYC 9334 32-Core Processor
  Name:                    gfx1100
  Marketing Name:          AMD Radeon Pro W7900D
      Name:                amdgcn-amd-amdhsa--gfx1100
```
- Radeon Pro W7900D (card model 0x744c, SKU D7070910), gfx1100, 48 GB VRAM (51,522,830,336 B total).
- Matches 00-system.txt exactly. Single GPU (device count 1).

### 2. torch import works — VERIFIED
```
$ python -c "import torch; print(torch.__version__, torch.version.hip, torch.cuda.get_device_name(0))"
2.13.0+rocm7.14.0 7.14.60850 AMD Radeon Pro W7900D
```
- Direct torch import (before any vllm import) works — consistent with the known ROCm 7.2.1-toolchain / 7.14-torch library collision described in the mission brief. Matches 01-python.txt.
- Environment uses /opt/venv (Python 3.12.3, pip 26.0.1). hipcc reports HIP 7.14.60850 on ROCm 7.2.1 LLVM (`roc-7.2.1` clang 22.0.0git, InstalledDir /opt/rocm-7.2.1/...). This mix is noted as a known machine quirk, not a contamination.

### 3. Disk / RAM — VERIFIED
```
$ df -h /
overlay  3.5T  1.3T  2.1T  39%  /        → 2.1 TB free on root overlay (> 500 GB required) ✓
$ free -g
Mem: 503 total, 432 available  → ample ✓   Swap: 0
```

### 4. No vLLM/GPU process consuming VRAM — VERIFIED (with note)
```
$ rocm-smi --showmeminfo vram | grep -E 'GPU|Total'
GPU[0]: VRAM Total Memory (B): 51522830336
GPU[0]: VRAM Total Used Memory (B): 28004352      → 28 MB of 51.5 GB (~0.05%) — idle ✓
$ pgrep -af 'vllm|EngineCore'
65680 [vllm-omni] <defunct>
71742 [vllm-omni] <defunct>
```
- **NOTE (non-blocking):** two `vllm-omni` entries are zombies: `ps` shows `STAT=Zs`, `PPID=1` — defunct reaped-pending corpses that hold **no VRAM and no host memory** and cannot run kernels. Not contaminants; VRAM telemetry confirms idle.

### 5. Background vLLM build — VERIFIED (expected, distinguished from GPU strays)
```
$ pgrep -af "pip install -e" | head -3
436407 /opt/venv/bin/python3.12 /opt/venv/bin/pip install -e . --no-deps --no-build-isolation
```
- One CPU-only build process (editable install), matching the brief's expectation. No GPU processes besides zombies.

### Additional notes (for later phases)
- **/workspace is a 98 GB loop mount with only ~19 GB free now** (was 9.8 GB in the 03-resources.txt snapshot). HF caches (`HF_HOME=/workspace/.cache/huggingface`, hub/assets/datasets) live on this small mount. The model itself downloads to `/opt/models` (on /, 2.1 TB free) so model storage is safe, but any large incidental HF-hub writes would land on the tight mount. Monitor.
- `HF_ENDPOINT=https://hf-mirror.com` is set — downloads use the mirror; fine, but a later failure mode to remember if a fetch 404s.
- `PYTORCH_ROCM_ARCH` includes gfx1100 — consistent with a gfx1100-targeted editable build in progress.
- Env files 00–03 internally consistent with live system (only drift: /workspace free space fluctuated 9.8→19 GB, explained by build activity).

---

## VERDICT CHECKPOINT 2 — Git provenance: **PASS**

All seven checks independently re-verified with live git + GitHub API.

### 1. 28c57456 is an older upstream/main commit (valid PR base) — VERIFIED
```
$ git -C /root/vllm fetch upstream main; git -C /root/vllm rev-parse upstream/main
44198f577fe5cfb4b02297bf6ff7235eb31d742b          (upstream/main has moved on, as expected)
$ git -C /root/vllm merge-base --is-ancestor 28c57456... upstream/main && echo IS-ancestor
28c57456 IS ancestor of upstream/main              ✓
```
Also matches 04-git-provenance.txt: merge-base(base, upstream/main) = 28c57456.

### 2. Exactly 3 commits, all [ROCm][RDNA3] — VERIFIED
```
$ git -C /root/vllm log --oneline 28c57456..16ce8ac8
16ce8ac8 [ROCm][RDNA3] Fuse the fp16 deterministic split-K reduction into the kernel
590ece2c [ROCm][RDNA3] Exact fp16 W4A16 dequant; WMMA dispatch from M>=12
e1da076e [ROCm][RDNA3] Fix W4A16 split-K accuracy and determinism
```
Exactly 3 commits; every title prefixed `[ROCm][RDNA3]`. ✓

### 3. PR stack sits directly on the base — VERIFIED
```
$ git -C /root/vllm rev-parse e1da076e^
28c57456db9220fbdde6041a20b97bebd141259b          == BASE_SHA ✓
```

### 4. Exactly 5 files changed, matching the expected list — VERIFIED
```
$ git -C /root/vllm diff --stat 28c57456..16ce8ac8
 csrc/rocm/moe_q_gemm_rdna3.cu                              |  82 +++---
 csrc/rocm/q_gemm_rdna3.cu                                  | 582 ++++++---
 csrc/rocm/q_gemm_rdna3_wmma.cu                             | 435 ++++--
 csrc/rocm/qdq_4_rdna3.cuh                                  | 106 ++--
 tests/kernels/quantization/test_rdna3_w4a16_determinism.py | 585 ++++++
 5 files changed, 1524 insertions(+), 266 deletions(-)
```
File set identical to the mission spec (4 RDNA3 kernel headers/sources + 1 new test). ✓

### 5. Worktrees exist at correct HEADs, both clean — VERIFIED
```
/root/wt-e2e-baseline: HEAD=28c57456db9220fbdde6041a20b97bebd141259b, status --porcelain | wc -l = 0
/root/wt-e2e-pr:       HEAD=16ce8ac88955bc230793462d1c1b6ac77eea0e04, status --porcelain | wc -l = 0
```
Both detached HEADs, zero uncommitted changes. (`git worktree list` also shows unrelated older worktrees wt-baseline/wt-gfx942/wt-hybrid/wt-orig from prior exercises — not part of this A/B, no interference.)

### 6. GitHub API cross-check — VERIFIED
```
$ curl -s https://api.github.com/repos/vllm-project/vllm/pulls/54706 | ...
16ce8ac88955bc230793462d1c1b6ac77eea0e04 28c57456db9220fbdde6041a20b97bebd141259b open
```
head == PR_SHA, base == BASE_SHA, PR open. Matches 04-git-provenance.txt metadata. ✓

### 7. Scientific validity of the baseline — SOUND
- Base 28c57456 is the exact parent of the first PR commit (check 3), an ancestor of upstream/main (check 1), and the only difference between arms is the 3 PR commits touching 5 files (checks 2, 4).
- Both worktrees clean ⇒ no uncontrolled source diffs. Any output divergence between arms is attributable to the PR diff alone (toolchain held constant by using the same build env for both — must be confirmed in the build checkpoint).

---

## Model-choice rationale — **CORRECT KIND OF CHECKPOINT** (runtime routing proof deferred)

### Checkpoint present and correct
- `/opt/models/gemma-3-27b-it-w4a16/config.json` exists; download **actively running** (pid 436198: `hf download RedHatAI/gemma-3-27b-it-quantized.w4a16 --revision 2b537554d6c6f6368945e8df4e5fb7bbbb5d56c9 --local-dir /opt/models/gemma-3-27b-it-w4a16` — repo + revision match the mission). ~26 GB on disk at check time; 4/4 safetensors shards still in flight (0 finalized) — completion must be re-verified in a later checkpoint.
- Verified from config.json + recipe.yaml:
  - `quant_method: compressed-tensors`, `format: pack-quantized` ✓
  - weights: `num_bits=4`, `group_size=128`, `symmetric=true`, `strategy=group`, `type=int`, `observer=mse`, `actorder=weight` ✓
  - `targets: ["Linear"]` (per config_groups group_0) ✓
  - text_config `hidden_size=5376` and 5376/128 = 42.0 exactly ⇒ group_size divides K ✓

### Kernel acceptance (static assessment of /root/vllm/vllm/model_executor/kernels/linear/mixed_precision/rdna3_w4a16.py)
- `can_implement` gates: ROCm + `on_gfx1100()` ✓ (this machine), act fp16/bf16 ✓, weight type ∈ {uint4b8} ✓, group_size>0 and divides K ✓, partition N%8==0 (gemma-3-27b linear Ns are multiples of 8; definitive proof at runtime) — checkpoint is the right kind.
- **uint4b8 mapping confirmed in-tree:** compressed-tensors W4A16 *symmetric* selects `WNA16_SUPPORTED_TYPES_MAP[4] = scalar_types.uint4b8` (vllm/model_executor/layers/quantization/compressed_tensors/schemes/compressed_tensors_wNa16.py:36-44, 96-98); asymmetric would select uint4 (zero-point map). Our checkpoint is symmetric ⇒ uint4b8 ⇒ matches `SUPPORTED_QUANT_TYPES`.
- `actorder="weight"` is accepted: compressed_tensors.py:330-339 rejects only `GROUP`/`DYNAMIC` actorder, not `weight`. ✓

### Independent reviewer evidence
- raw.githubusercontent.com is unreachable from this machine (HTTP 000), but api.github.com works; fetched `cadamcat/dual-radeon-vllm/benchmarks/gfx1100-w4a16-54706/run_c1_ab.sh` via the contents API. Script confirms a same-class methodology: A/B swapping only `_rocm_C.abi3.so` (baseline vs PR-built), gemma3 model, ROCM_ATTN backend, and it greps `Using [A-Za-z0-9]+LinearKernel` from engine logs to prove kernel routing on that machine. Supports plausibility of the routing claim; routing on THIS machine remains a later checkpoint.

---

## Concerns for later phases
1. **Model download incomplete** — 0/4 safetensors shards finalized (~26 GB staged in .cache blobs). Later checkpoint must confirm all 4 shards + index integrity before serving.
2. **Build in flight** — editable `pip install -e` (pid 436407) still running; later checkpoints must confirm it finished and which worktree/source it was built from (it appeared to run in /root/vllm @ 16ce8ac8; BASE-arm binary still needs its own build or .so swap).
3. **/workspace capacity** — ~19 GB free on a 98 GB loop with all HF caches; avoid large hub downloads there.
4. **Zombie vllm-omni processes** — harmless (Zs, PPID 1, no VRAM) but if a later checkpoint counts processes, exclude defunct entries.
5. **Network** — raw.githubusercontent.com blocked; use api.github.com for external evidence.
6. **Torch/ROCm library collision** — import order (torch before vllm) matters on this box; keep it in test harnesses.
7. **HIP 7.14 torch vs ROCm 7.2.1 toolchain** — known-good here, but both A/B arms must be built with the identical toolchain for attribution.

---

## Summary
- **VERDICT CHECKPOINT 1: PASS WITH NOTES** — gfx1100 W7900D real, torch imports clean, 2.1 TB free on /, 432 GB RAM, VRAM idle (28 MB), expected background build running. Notes: zombie vllm-omni procs (no resources), small /workspace mount for HF caches.
- **VERDICT CHECKPOINT 2: PASS** — PR head/base match GitHub API (open PR), exactly 3 [ROCm][RDNA3] commits stacked directly on 28c57456, exactly the 5 expected files, both worktrees at correct HEADs and clean; base is a scientifically valid baseline. Model checkpoint is the right kind (compressed-tensors W4A16 symmetric pack-quantized, gs=128 | K=5376, → uint4b8 → RDNA3W4A16 kernel accepts); runtime routing proof correctly deferred.
