# Independent Verification Report — Checkpoints 3, 4, 5 (baseline arm)

**Verifier:** independent adversarial subagent (no claims trusted; all evidence re-collected)
**Date:** 2026-10-03 ~02:45 UTC
**Scope:** Checkpoint 3 (model qualifies for RDNA3W4A16LinearKernel), Checkpoint 4 (clean baseline build), Checkpoint 5 (baseline runtime kernel routing)

## Verdicts

- **CHECKPOINT 3 — PASS.** compressed-tensors W4A16 symmetric pack-quantized, gs=128 | K=5376, targets=Linear, uint4b8 mapping confirmed in source (compressed_tensors_wNa16.py:36-44,95-99; rdna3_w4a16.py can_implement). All 4 shards + index present; all sha256 recomputed and matching model-hashes.txt; download provenance RedHatAI/gemma-3-27b-it-quantized.w4a16 @ 2b537554d6c6f6368945e8df4e5fb7bbbb5d56c9 confirmed via HF .metadata etags + live ps capture in checkpoint-1-2 report.
- **CHECKPOINT 4 — PASS WITH NOTES.** HEAD=28c57456, worktree clean; _rocm_C.abi3.so valid ELF, 85 rdna3 symbols, md5 83500bc9... newer than checkout; venv editable = dev538+g28c57456d (baseline); build.log successful install; health-check PASS. NOTES (remediated): (a) build.log previously ended with unexplained AssertionError false alarm → explanatory NOTE appended; (b) install-identity.txt omitted dirty-entries line → note appended (fact re-verified independently: 0 dirty entries).
- **CHECKPOINT 5 — PASS WITH NOTES.** server.log: exactly one engine launch; `Using RDNA3W4A16LinearKernel for mixed-precision linear` and `for CompressedTensorsWNA16` from EngineCore 505672 at 02:28:48; zero hits for Exllama/Marlin/TritonW4A16/awq (no competing kernel). Decisive: /proc/505401/maps and /proc/505672/maps both map /root/wt-e2e-baseline/vllm/_rocm_C.abi3.so — live server runs the baseline build. Determinism JSON: prompt sha256s match frozen prompt files; ctx512=1/8, ctx8192=2/8; all 16 stored text hashes recomputed and genuine (divergence at char 66: "two key historical" vs "two historical"). NOTE (remediated): baseline/server.pid was missing → recreated with pid 505401; process identity independently proven via ps/ss//proc anyway.

## OVERALL: PASS WITH NOTES
(all three notes were documentation defects, remediated in-place; no substantive issue found)
