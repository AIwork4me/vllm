# Independent Verification Report — Checkpoints 6-11 (greedy A/B, baseline lm-eval, PR build/routing)

**Verifier:** independent adversarial subagent (evidence re-collected, metrics recomputed from raw samples)
**Date:** 2026-10-03 ~04:0x UTC (while PR full GSM8K in flight)

## Verdicts

- **CHECKPOINT 6 — PASS.** Probe: temperature=0.0, seed=1234, max_tokens=64, same script both arms; prompt sha256 recomputed and matching frozen files. Recount from stored texts: baseline ctx512=1/8 (e8eebe8a×8), ctx8192=2/8 (ff74c672×5, 2b0de610×3).
- **CHECKPOINT 7+8 — PASS.** results.json: original=1319, effective=1319, limit null, 5-shot, lm_eval 0.4.13, local-completions → :8000/v1/completions. Both metrics recomputed from 2638 sample lines (1319 unique doc_ids × 2 filters): strict 0.8362395754359363, flexible 0.8430629264594389 — exact match to results.json. Window 02:53:12Z→03:37:16Z; exactly ONE engine init in server.log (dev538+g28c57456d) + RDNA3W4A16LinearKernel routing from that init; no crash/restart during window.
- **CHECKPOINT 9 — PASS WITH NOTES.** PR worktree HEAD 16ce8ac8 clean; build HEALTH CHECK PASS; serve-time .so md5 9c51583d... matches on-disk AND the live process mapping (inode-checked); differs from baseline's 83500bc9...; git diff BASE..PR = exactly 4 csrc/rocm files + 1 test file; vllm/ python trees identical (only gitignored build artifacts + version string differ); requirements identical; single editable .pth (PR). NOTE (documented): .so md5 churn build-time vs serve-time (0340bfb7→9c51583d) is inherent to the shared-venv re-point design, affects both arms equally, self-documented in artifacts; attribution intact.
- **CHECKPOINT 10 — PASS.** patched/server.log: one engine init v0.30.1rc1.dev541+g16ce8ac88, RDNA3W4A16LinearKernel×2, zero errors; live :8000 process maps /root/wt-e2e-pr/vllm/_rocm_C.abi3.so, zero baseline mappings.
- **CHECKPOINT 11 — PASS.** PR greedy: ctx512=1/8, ctx8192=1/8. Cross-arm: ctx512 output hash identical across arms (e8eebe8a); PR ctx8192 output (2b0de610) ∈ baseline's {ff74c672, 2b0de610} — the deterministic reduction converged to an ordering the baseline could produce; no novel output. Timeline integrity verified (prompts frozen 01:28 < baseline runs < baseline teardown 03:40 < PR serve 03:47 < PR greedy 03:50).

## OVERALL: PASS
