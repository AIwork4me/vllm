# vLLM PR #54706 — gfx1100 End-to-End Validation

## Why this evaluation

The W4A16 issue leading to #54706 was originally isolated on `Muse-Glimmer-30B-INT4` on gfx1100.
`gemma-3-27b-it-w4a16` independently exercises the same affected `RDNA3W4A16LinearKernel`
(compressed-tensors W4A16 symmetric, uint4b8, group_size 128) and reproduces the same class of
greedy non-determinism, so it is used here for the requested standard end-to-end lm-eval A/B.
The scope of the PR is the gfx11/RDNA3 W4A16 kernel path itself, not any single model.

## Environment

- GPU: 1x AMD Radeon Pro W7900D — **gfx1100** (rocminfo `amdgcn-amd-amdhsa--gfx1100`, capability (11,0)), 48 GB VRAM, TP=1
- ROCm: ROCk 6.16.13 kernel module; HIP runtime 1.21; torch ships HIP 7.14.60850 (venv `_rocm_sdk_core`), toolchain hipcc ROCm 7.2.1 LLVM — pre-existing machine configuration, identical for both arms
- PyTorch: 2.13.0+rocm7.14.0 (Python 3.12.3, /opt/venv)
- vLLM baseline SHA: `28c57456db9220fbdde6041a20b97bebd141259b` (exact parent of the PR's first commit; see `results/revision-rationale.md`)
- vLLM PR SHA: `16ce8ac88955bc230793462d1c1b6ac77eea0e04` (current PR #54706 head, GitHub-verified 2026-10-03)
- Diff between arms: exactly 4 `csrc/rocm/*` kernel files + 1 new test file — **zero Python source changes**
- Model: `RedHatAI/gemma-3-27b-it-quantized.w4a16` @ revision `2b537554d6c6f6368945e8df4e5fb7bbbb5d56c9` (local: `/opt/models/gemma-3-27b-it-w4a16`; hashes in `environment/model-hashes.txt`)
- lm-eval: 0.4.13 (`local-completions` against the served model's OpenAI-compatible API)

### Environment quirks (identical for both arms; see `scripts/vllm_cli.sh`)

1. `LD_LIBRARY_PATH` must put the venv's ROCm 7.14 libs ahead of system 7.2.1 (soname race otherwise breaks `import torch` inside vLLM's `env_override`).
2. `amdsmi` cannot co-exist with an initialized ROCm runtime in one process on this box, so vLLM's builtin ROCm platform *detection* fails; the pip-installed out-of-tree plugin `vllm-gfx1100-rocm-platform-plugin` (env-gated by `FORCE_ROCM_PLATFORM=1`) selects the same `vllm.platforms.rocm.RocmPlatform` class. Detection only — no kernel or numerics code is touched.
3. Both arms share one venv and are switched by `pip install -e <worktree>` re-point (identical procedure, documented per-arm in `install-identity.txt` with serve-time `.so` md5 and HEAD).

## Routing

Baseline: `Using RDNA3W4A16LinearKernel for CompressedTensorsWNA16` + `for mixed-precision linear` (EngineCore, `baseline/server.log`) — confirmed

PR: `Using RDNA3W4A16LinearKernel` ×2 (EngineCore, `patched/server.log`) — confirmed

Independent verifier additionally proved via `/proc/<pid>/maps` that each live server mapped its own arm's `_rocm_C.abi3.so`, and that no competing W4A16 kernel (Exllama/Marlin/Triton) appeared in either log.

## Full GSM8K (1319/1319 examples in both arms, 5-shot, temperature=0)

| metric | baseline (28c57456) | PR #54706 (16ce8ac8) | delta |
|---|---:|---:|---:|
| exact_match, strict-match | 0.8362 | 0.8347 | −0.0015 |
| exact_match, flexible-extract | 0.8431 | 0.8408 | −0.0023 |
| stderr (strict / flexible) | 0.0102 / 0.0100 | 0.0102 / 0.0101 | — |
| evaluated examples | 1319 | 1319 | — |

Paired per-example (strict-match): correct→wrong 22, wrong→correct 20, unchanged 1277 (1081 correct + 196 wrong).
(For reference, flexible-extract flips: 23 / 20 / 1276.)
Raw aggregates recomputed from per-sample JSONL by an independent verifier — exact match to results.json.

**Conclusion supported by the data:** no material end-to-end accuracy regression on full GSM8K; the deltas (−0.15 pp strict, −0.23 pp flexible) are ≈0.15–0.23 of one standard error, with near-symmetric per-example flips (strict: 22 vs 20).

## Fixed-input greedy repeatability (8 sequential generations × 64 tokens, temperature=0, same server instance)

| context | baseline | PR #54706 |
|---|---:|---:|
| ~448-token prompt | 1/8 distinct | 1/8 distinct |
| ~8128-token prompt | **2/8 distinct** | **1/8 distinct** |

The baseline produced two different greedy outputs at the 8192 context (divergence at char 66 of the 64-token completion). The PR produced a single output in all 8 runs — and that output's hash is one of the two the baseline could produce (a fixed-order reduction selects one of the previously-possible orderings; it does not invent a new answer). The 512-context output is byte-identical across arms.

## PR's own kernel test suite (run once, PR arm)

`tests/kernels/quantization/test_rdna3_w4a16_determinism.py`: **54 passed, 0 failed** (a first `-x` run stopped on a torch.profiler first-session warmup flake that captured zero kernel names — `AssertionError: set()` — before any numerics assertion; full re-run passed everything including that test). Log: `patched/pr-determinism-testsuite.log`.

## Commands

### Baseline server

```bash
/workspace/validation-54706-e2e/scripts/serve_arm.sh baseline /workspace/validation-54706-e2e/baseline
# which runs, after re-pointing the venv to /root/wt-e2e-baseline (BASE_SHA):
vllm serve /opt/models/gemma-3-27b-it-w4a16 \
  --tensor-parallel-size 1 --dtype bfloat16 \
  --gpu-memory-utilization 0.92 --max-model-len 8192 \
  --host 127.0.0.1 --port 8000
```

### Baseline lm-eval (full)

```bash
lm_eval --model local-completions \
  --model_args model=/opt/models/gemma-3-27b-it-w4a16,base_url=http://127.0.0.1:8000/v1/completions,tokenizer_backend=huggingface,num_concurrent=8,max_retries=5 \
  --tasks gsm8k --num_fewshot 5 --log_samples \
  --output_path .../baseline/lm_eval/full
```

### PR server

```bash
/workspace/validation-54706-e2e/scripts/serve_arm.sh pr /workspace/validation-54706-e2e/patched
# identical vllm serve flags (same model, TP, dtype, memory, len, port)
```

### PR lm-eval (full)

```bash
# identical lm_eval invocation, output_path .../patched/lm_eval/full
```

### Greedy probe (both arms)

```bash
python3 scripts/greedy_probe.py <arm> <outdir>   # frozen prompts in results/prompts/
```

## Timeline (UTC, 2026-10-03)

01:28 prompts frozen → 02:28 baseline server up (dev538+g28c57456d) → 02:33 baseline greedy → 02:53–03:37 baseline full GSM8K → 03:40 baseline teardown (VRAM idle) → 03:47 PR server up (dev541+g16ce8ac88) → 03:50 PR greedy → 03:52–04:37 PR full GSM8K → 04:4x PR teardown → PR kernel test suite 54/54.

## Independent verification

All checkpoints verified by independent adversarial subagents that re-collected evidence (recomputed metrics from raw samples, recounted hashes, checked /proc maps, git provenance):

- `verification/checkpoint-1-2-environment-git.md` — PASS / PASS
- `verification/checkpoint-3-4-5-baseline-model-build-routing.md` — PASS / PASS WITH NOTES (remediated) / PASS WITH NOTES (remediated)
- `verification/checkpoint-6-11-greedy-lmeval-pr.md` — PASS (all six)
- `verification/final-adversarial-review.md` — final review

## Conclusion

Only what the evidence supports:

1. `gemma-3-27b-it-w4a16` is a real affected model: it routes its quantized Linear layers through `RDNA3W4A16LinearKernel` on gfx1100, and its baseline greedy decoding is non-deterministic at 8192 context (2 distinct outputs / 8 runs) on the exact BASE parent of PR #54706.
2. PR #54706 makes that generation deterministic (1/8) under an identical protocol, converging to one of the orderings the baseline could produce.
3. Full GSM8K (1319 examples, both arms, identical serving and eval configuration) shows no material accuracy change: −0.15 pp strict / −0.23 pp flexible, ≈0.15–0.23 σ, with 22↔20 (strict) near-symmetric per-example flips.
4. Muse-Glimmer-30B-INT4 remains the original model-level reproducer that isolated the issue; Gemma was used for the standard end-to-end lm-eval A/B requested by the reviewer.

---

## Correction note (final adversarial review, 2026-10-03)

An early version of the paired-flip line in the GSM8K section labeled the flexible-extract flips
(23/20/1276) as strict-match — a filter-overwrite bug in `scripts/07_compare.py` (loading samples
keyed by doc_id only, so the flexible line overwrote the strict line). The final adversarial
reviewer recomputed both from the raw samples JSONL; `07_compare.py` was fixed (keyed by
(doc_id, filter)) and this README plus `PR_REPLY.md` now carry the corrected numbers:

- strict-match: correct→wrong **22**, wrong→correct **20**, unchanged **1277** (1081 correct + 196 wrong)
- flexible-extract: correct→wrong **23**, wrong→correct **20**, unchanged **1276** (1089 + 187)

All aggregate scores in the table are unaffected and were independently verified against the raw
samples (baseline strict 1103/1319 = 0.83624, PR strict 1101/1319 = 0.83472; flexible 1112 and
1109). The near-symmetry conclusion holds under both metrics.
