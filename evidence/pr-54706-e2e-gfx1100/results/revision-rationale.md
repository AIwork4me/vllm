# Revision rationale — PR #54706 end-to-end A/B on gfx1100

## SHAs

```
BASE_SHA = 28c57456db9220fbdde6041a20b97bebd141259b
PR_SHA   = 16ce8ac88955bc230793462d1c1b6ac77eea0e04   (current PR #54706 head)
```

## Why this baseline is the correct control

1. **GitHub-verified PR head:** the GitHub API (`pulls/54706`, fetched 2026-10-03) reports
   `head.sha = 16ce8ac8…` and `base.sha = 28c57456…`, state `open`. The historical PR head
   from the original investigation is identical to the current head — the PR has not moved.
   Both SHAs are recorded; no discrepancy to explain.

2. **Direct parentage:** `git rev-parse e1da076e^` (first PR commit's parent) =
   `28c57456…` = BASE_SHA. The PR stack sits *directly* on the base — no intermediate
   commits, no merge commits.

3. **Minimal diff:** `git diff --stat BASE..PR` = exactly 5 files, all `[ROCm][RDNA3]`:
   ```
   csrc/rocm/moe_q_gemm_rdna3.cu                              |  82 +++---
   csrc/rocm/q_gemm_rdna3.cu                                  | 582 ++++++---
   csrc/rocm/q_gemm_rdna3_wmma.cu                             | 435 ++++++--
   csrc/rocm/qdq_4_rdna3.cuh                                  | 106 ++--
   tests/kernels/quantization/test_rdna3_w4a16_determinism.py | 585 ++++++
   ```
   Only compiled-kernel sources (+ a new test). **No Python source changes** — so the
   A/B isolates the kernel epilogue change and nothing else.

4. **Ancestry:** `merge-base BASE upstream/main` = BASE itself (BASE is an ancestor of
   upstream/main). Both arms share the identical Python code, venv, PyTorch, ROCm
   toolchain, and model files; the only effective binary difference is the compiled
   `_rocm_C.abi3.so`.

## Why not an older release / main HEAD?

- An arbitrary old release would import hundreds of unrelated changes (attention
  backends, schedulers, quant code paths) that could dominate or mask the effect —
  scientifically invalid for attributing an A/B delta to this PR.
- Upstream `main` (44198f57… at fetch time) has moved past the PR base; building main
  as one arm would mix an uncontrolled version gap into the comparison. The reviewer's
  question is about *this PR's* end-to-end effect, so the exact base-parent control is
  the correct choice.
