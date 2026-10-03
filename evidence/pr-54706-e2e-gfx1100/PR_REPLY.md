Thanks @tjtanaa — I ran the requested end-to-end A/B on gfx1100 (Radeon Pro W7900D).

The W4A16 issue leading to #54706 was originally isolated on `Muse-Glimmer-30B-INT4`.
`gemma-3-27b-it-w4a16` (compressed-tensors W4A16, symmetric uint4b8, group_size 128) was
independently confirmed to exercise the same affected `RDNA3W4A16LinearKernel`, so I used
Gemma for the standard end-to-end lm-eval A/B below.

### Environment

- GPU: 1x AMD Radeon Pro W7900D (gfx1100), TP=1
- ROCm: ROCk 6.16.13; torch 2.13.0+rocm7.14.0
- baseline: `28c57456` (exact parent of the PR's first commit)
- PR: `16ce8ac8` (#54706 head; diff = 4 `csrc/rocm` kernel files + 1 test file, no Python changes)
- model: `RedHatAI/gemma-3-27b-it-quantized.w4a16` @ `2b537554`
- lm-eval: 0.4.13, `local-completions` against the served model

### End-to-end commands

Server (identical for both arms; only the vLLM revision differs):

```bash
vllm serve RedHatAI/gemma-3-27b-it-quantized.w4a16 \
  --tensor-parallel-size 1 --dtype bfloat16 \
  --gpu-memory-utilization 0.92 --max-model-len 8192 \
  --host 127.0.0.1 --port 8000
```

Evaluation (identical for both arms):

```bash
lm_eval --model local-completions \
  --model_args model=<model>,base_url=http://127.0.0.1:8000/v1/completions,tokenizer_backend=huggingface,num_concurrent=8,max_retries=5 \
  --tasks gsm8k --num_fewshot 5 --log_samples --output_path <out>
```

### Routing

Both baseline and PR runs confirmed in engine logs (and via `/proc/<pid>/maps` of the live
servers): `Using RDNA3W4A16LinearKernel for CompressedTensorsWNA16`.

### Full GSM8K (1319/1319 examples in each arm)

| metric | baseline `28c57456` | #54706 `16ce8ac8` | delta |
|---|---:|---:|---:|
| exact_match, strict-match | 0.8362 | 0.8347 | −0.0015 |
| exact_match, flexible-extract | 0.8431 | 0.8408 | −0.0023 |

Evaluated examples: `1319` per arm. Paired per-example (strict): 22 correct→wrong vs 20
wrong→correct (1277 unchanged). The deltas are ≈0.15–0.23 of one standard error (σ ≈ 0.010).

### Fixed-input greedy repeatability (8 runs × 64 tokens, temperature=0, same server)

- baseline: `1` distinct / 8 at ~512 ctx, **`2` distinct / 8** at ~8192 ctx
- #54706: `1` distinct / 8 at ~512 ctx, **`1` distinct / 8** at ~8192 ctx

The PR's single 8192-ctx output is one of the two orderings the baseline produced (fixed-order
reduction selects a previously-possible result; the ~512-ctx output is byte-identical across arms).
The PR's own kernel test suite (`test_rdna3_w4a16_determinism.py`) also passes 54/54 on this GPU.

No material end-to-end accuracy regression was observed in the full GSM8K A/B, and the baseline's
model-level greedy non-determinism disappears with the PR.

Full raw logs, commands, routing evidence, per-sample outputs and independent verification reports:
https://github.com/AIwork4me/vllm/tree/evidence/pr-54706-e2e-gfx1100/evidence/pr-54706-e2e-gfx1100
