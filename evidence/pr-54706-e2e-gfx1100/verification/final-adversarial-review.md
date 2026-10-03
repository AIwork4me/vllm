# Final Adversarial Review — vLLM PR #54706 gfx1100 End-to-End Validation

**Reviewer:** final independent adversarial reviewer (read-only re-verification of all 13 dimensions; every number below re-derived from primary evidence)
**Date:** 2026-10-03 (post-experiment)
**Inputs challenged:** README.md (claims document), PR_REPLY.md, all artifacts under baseline/, patched/, environment/, results/, scripts/, verification/, both git worktrees, the model directory, and the live system state.

---

## Dimension 1 — Baseline SHA ✅

```
$ git -C /root/wt-e2e-baseline rev-parse HEAD
28c57456db9220fbdde6041a20b97bebd141259b
$ git -C /root/wt-e2e-pr rev-parse e1da076e^
28c57456db9220fbdde6041a20b97bebd141259b
```
Exact match; `git status --porcelain` empty on both worktrees. Baseline is the exact parent of the PR's first commit. **Verified.**

## Dimension 2 — PR SHA and diff scope ✅

- `/root/wt-e2e-pr` HEAD = `16ce8ac88955bc230793462d1c1b6ac77eea0e04`, clean.
- `git log 28c57456..16ce8ac8`: exactly 3 `[ROCm][RDNA3]` commits (e1da076e, 590ece2c, 16ce8ac8).
- `git diff --stat 28c57456..16ce8ac8`: exactly the 5 expected files — `csrc/rocm/{moe_q_gemm_rdna3.cu, q_gemm_rdna3.cu, q_gemm_rdna3_wmma.cu, qdq_4_rdna3.cuh}` + `tests/kernels/quantization/test_rdna3_w4a16_determinism.py` (1524+/266−).
- `environment/pr-54706.diff` (2291 lines) is line-identical to a freshly regenerated `git diff` (only blob-hash abbreviation width differs).
- **Python trees:** full `.py`-by-`.py` scan of `vllm/` (file lists identical; `cmp` of every file): the ONLY differing `.py` is `vllm/_version.py`, which differs solely in the setuptools_scm-generated version string (`dev538+g28c57456d` vs `dev541+g16ce8ac88`). Remaining `diff -rq` hits are build artifacts (`.so` files, `vllm-rs` rust binary) — zero Python source changes. **Verified.**

## Dimension 3 — Model revision and integrity ✅

- All four shards + config + tokenizer recomputed on disk and matched `environment/model-hashes.txt` exactly:
  - `config.json` → `dea28bf9…` ✓; `tokenizer.json` → `c5c1a32d…` ✓
  - shard 1 `3cfd73ad…` ✓, shard 2 `e3a0330e…` ✓, shard 3 `69cd48fb…` ✓, shard 4 `09c2a416…` ✓
- Revision `2b537554d6c6f6368945e8df4e5fb7bbbb5d56c9` recorded in every `.cache/huggingface/download/*.metadata` etag file; download command with `--revision 2b537554…` captured live in checkpoint-1-2. Download logs show xet-bridge timeouts with successful resumes; leftover `.incomplete` cache blobs are harmless resume artifacts (final files hash-verified). **Verified.**

## Dimension 4 — Tokenizer identity ✅

- Server role, both arms (engine init line 18 of each server.log): `tokenizer='/opt/models/gemma-3-27b-it-w4a16'`, `skip_tokenizer_init=False`, `tokenizer_mode=auto`.
- lm-eval role, both arms (results.json configs + lm_eval_stdout.txt): `tokenizer_backend: 'huggingface'`, `model: /opt/models/gemma-3-27b-it-w4a16`.
- Same tokenizer path in all four roles. **Verified.**

## Dimension 5 — Build contamination / install identity ✅ (with documented notes)

- `install-identity.txt` (baseline): vllm file `/root/wt-e2e-baseline/vllm/__init__.py`, HEAD `28c57456`, serve-time `.so` md5 `83500bc96b72c7bce4cf4cc770dea090`.
- `install-identity.txt` (PR): `/root/wt-e2e-pr/...`, HEAD `16ce8ac8`, dirty=0, md5 `9c51583dbfc2e9a8014518548fa7721b`.
- Current on-disk md5s (recomputed now): `83500bc9…` (baseline) and `9c51583d…` (PR) — **match the serve-time records and differ between arms**.
- md5 churn is real and documented: baseline `.so` md5 was `1eeaec37…` at first build/health-check time → `83500bc9…` after the 02:22 editable re-point rebuild (appended NOTE in baseline/build.log); PR `.so` `0340bfb7…` at build time → `9c51583d…` at serve (checkpoint-9). Both rebuilds ran `pip install -e . --no-deps --no-build-isolation` from clean worktrees (dirty=0 proven), so the served binaries derive from the pinned sources.
- **Attribution does not rest on md5 alone:** the checkpoint verifiers proved via `/proc/<pid>/maps` (inode-checked, APIServer + EngineCore) that each live server mapped its own arm's `_rocm_C.abi3.so` at serve time, and current on-disk md5s still equal the serve-time recorded ones (no rebuild after the runs). Attribution intact. The shared-venv re-point design is symmetric (same `serve_arm.sh` flow both arms).
- venv today: single editable vllm (`dev541+g16ce8ac88` → `/root/wt-e2e-pr`) + `vllm-gfx1100-rocm-platform-plugin 0.1.0` — consistent with PR-last ordering. **Verified.**

## Dimension 6 — Kernel routing ✅

- baseline/server.log: `Using RDNA3W4A16LinearKernel for mixed-precision linear` (__init__.py:870) + `Using RDNA3W4A16LinearKernel for CompressedTensorsWNA16` (compressed_tensors_wNa16.py:138), from EngineCore pid 505672 (the one and only engine).
- patched/server.log: same two lines from EngineCore pid 511186.
- Zero hits for Exllama/Marlin/awq/other W4A16 kernels in either log. Engine version strings differ per arm (`v0.30.1rc1.dev538+g28c57456d` vs `…dev541+g16ce8ac88`). **Verified.**

## Dimension 7 — Server log hygiene ✅

- Exactly ONE `Initializing a V1 LLM engine` per log; single EngineCore pid per arm (505672 / 511186).
- Zero ERROR/WARNING/Traceback lines inside either eval window (baseline 02:53–03:37, PR 03:52–04:37 UTC).
- The only ERRORs are post-window teardown `EngineDeadError` after SIGTERM (03:40:07–09 baseline, 04:40:21–23 PR) — expected shutdown noise.
- No preemption events in either log. **Verified.**

## Dimension 8 — lm-eval configuration ✅

Both results_*.json: `lm_eval_version 0.4.13`; task gsm8k; `num_fewshot 5`; `limit: None`; identical model_args (`model=/opt/models/gemma-3-27b-it-w4a16`, `base_url=http://127.0.0.1:8000/v1/completions`, `tokenizer_backend=huggingface`, `num_concurrent=8`, `max_retries=5`); `temperature 0.0, do_sample False`; seeds identical (`random 0, numpy 1234, torch 1234, fewshot 1234` in both stdouts); `n-samples: original 1319 / effective 1319` both. Additionally, the per-doc `prompt_hash`/`doc_hash` sets are **identical across arms** (1319 per filter) — proving byte-identical few-shot contexts. **Verified.**

## Dimension 9 — Example counts and recomputed scores ✅ (one reporting defect, see D1)

Recomputed from raw samples JSONL (2638 lines = 1319 × 2 filters, both arms):

| | baseline | PR | README claim |
|---|---:|---:|---|
| strict-match | 1103/1319 = **0.8362395754** | 1101/1319 = **0.8347232752** | 0.8362 / 0.8347 ✓ |
| flexible-extract | 1112/1319 = **0.8430629265** | 1109/1319 = **0.8407884761** | 0.8431 / 0.8408 ✓ |

Exact match to results.json (full float precision) and to the README table; deltas −0.001516 / −0.002274 round to the claimed −0.0015 / −0.0023.

**D1 (defect):** the paired-flip line "strict-match: correct→wrong 23, wrong→correct 20, unchanged 1276 (1089 correct + 187 wrong)" (README L45, PR_REPLY L48, ab-summary.md) is **mislabeled** — those are the flexible-extract flips. True strict-match flips: **22 / 20 / 1277 (1081 + 196)**. Root cause: `scripts/07_compare.py` `load_samples()` keys by `doc_id` only, so the flexible-extract line overwrites the strict-match line per doc; the `exact_match[1]` list-handling branch is dead (values are scalars). Aggregate scores are unaffected (computed from results.json); the near-symmetry conclusion holds under both metrics (22↔20 strict, 23↔20 flexible).

## Dimension 10 — Score-file provenance ✅ (one transparency gap, see D2)

- baseline: results mtime 03:37:15.117, samples 03:37:15.242, stdout 03:37:15.302, timing 03:37:16.621; window start 02:53:12Z. All nested correctly; filename timestamp matches mtime.
- patched: results 04:37:08.581, samples 04:37:08.703, stdout 04:37:08.767, timing 04:37:11.104; window 03:52:17Z→04:37:11Z.
- **mtime == ctime on every results/samples/greedy JSON** → no post-hoc modification.
- Exactly one results + one samples file per full dir (no orphan/extra files).
- **D2 (transparency gap):** `baseline/lm_eval/full-runner.log` (mtime 02:37:19) records a first full-run attempt started 02:35:19 that was killed ~2 min in (~35/1319 requests served; no error in log), 16 minutes before the successful 02:53 run. Not mentioned in the README timeline. No contamination: attempt 1 wrote no results (killed mid-run), the published results derive solely from the 02:53 run, and the server did not restart (single engine init, up 02:28→03:40). Residual effect on attempt 2 is limited to prefix-cache/warm state — speed, not a numerics bias; and the measured claim is appropriately σ-hedged.

## Dimension 11 — Greedy inputs, outputs, convergence ✅

- Frozen prompts: `ctx512.txt` sha256 `0d7d2e87fd29427101eb877f8de9f87d6e8916b1647cf1cf7470545edf814507`, `ctx8192.txt` `e95829f96b616a544cf8d9b9b7fda6d6405575b8f374cf6e0a4dc11245094ea0` — both exact; mtimes 01:28:08 (frozen before all serving); token counts 443 / 8123 (≈ claims).
- All FOUR greedy JSONs carry the correct `prompt_sha256` for their context.
- Recounted from stored texts, recomputing every text hash (all genuine):
  - baseline ctx512: **1/8** (`e8eebe8a…` ×8); baseline ctx8192: **2/8** (`ff74c672…` ×5, `2b0de610…` ×3)
  - PR ctx512: **1/8** (`e8eebe8a…` ×8); PR ctx8192: **1/8** (`2b0de610…` ×8)
- Convergence claims verified: PR ctx8192 hash `2b0de610…` ∈ baseline's two hashes (it selects the baseline's minority ordering — the wording "one of the orderings the baseline could produce" is accurate and does not overclaim); ctx512 output byte-identical across arms.
- Baseline ctx8192 divergence at char 66 reproduced: `"…es on two key historical "` vs `"…es on two historical elem"`. **Verified.**

## Dimension 12 — Conclusions vs evidence ✅ (defects D1, D3)

- "No material accuracy regression" — worded as an observation with quantification ("deltas are ≈0.15–0.23 of one standard error"; PR_REPLY: "was observed"), not statistical identity. Supported: −0.0015/−0.0023 vs σ≈0.0102/0.0100; flips near-symmetric under both metrics. Acceptable.
- Deterministic-convergence wording — matches hash evidence exactly (dim 11); no overclaim (does not assert the majority ordering, does not claim "same answers everywhere"; GSM8K deltas are disclosed).
- Muse/Gemma framing — Muse-Glimmer-30B-INT4 cited only as the original reproducer for provenance; **no Muse scores and no #54210 historical numbers appear anywhere** (grep across the whole workspace: zero hits for "54210"). Gemma A/B evidence stands on its own artifacts.
- 54/54 test-suite claim vs `patched/pr-determinism-testsuite.log` — log shows first `-x` run: `FAILED test_dispatch_boundary[dtype0] - AssertionError: set()`, `1 failed, 34 passed`; then full re-run: `54 passed`. README discloses this accurately. Verified in source that `test_dispatch_boundary` asserts on **profiler-captured kernel names** (empty set → literal `AssertionError: set()`) at the first assertion (test line 438), before any numerics assertion (lines 449–450) — consistent with the documented rocprofiler first-session flake, not a numerics failure. "No code or environment change between runs" is plausible (same venv; no rebuild evidence; md5s of served .so unchanged).
- **D1** (above): mislabeled flip stats in README/PR_REPLY/ab-summary — corrected via appended notes in README.md and ab-summary.md; **PR_REPLY.md L48 must be fixed by the author before posting** (not edited by reviewer: outbound artifact).
- **D3 (cosmetic):** PR_REPLY shows `vllm serve RedHatAI/gemma-3-27b-it-quantized.w4a16` while the actual runs served the local path `/opt/models/gemma-3-27b-it-w4a16` (same repo @ 2b537554, hash-verified). README documents the real command.

## Dimension 13 — Alternative explanations for the A/B delta ✅ (residual notes, none biasing)

Controlled and verified identical across arms:
- Python source: byte-identical (dim 2). Deps: git-proven identical (only 5 files differ); single shared venv, one editable vllm at a time; same torch 2.13.0+rocm7.14.0 / HIP stack.
- Model files: identical (dim 3). Prompts: sha-pinned and identical (dim 11); GSM8K contexts identical (prompt-hash sets equal).
- Serve flags: `non-default args` lines identical (`model_tag/host/model/dtype/max_model_len`); `--gpu-memory-utilization 0.92` in effect in both (gpu_worker line: `--gpu-memory-utilization=0.9200` both; absent from non-default args only because 0.92 is this version's default; flag present in serve_arm.sh). Port/TP/enforce-eager/compile mode identical (engine init configs identical except version string).
- Seed: `seed=0` in both engine init lines. Prefix caching: `enable_prefix_caching=True` both. Attention backends: identical — decoder `TRITON_ATTN` (same "Overriding with TRITON_ATTN" lines), ViT "Flash Attention (Triton backend)", MMEncoder `FLASH_ATTN` both.
- Environment interventions: `vllm_cli.sh` is one shared script used by both arms (LD_LIBRARY_PATH venv-ROCm-first, `FORCE_ROCM_PLATFORM=1`, torch-first import, neutral cwd). `serve_arm.sh` flow is arm-symmetric (same re-point, identity check, serve, wait). The plugin selects the same `RocmPlatform` class the builtin would (detection-only; `platform: RocmPlatform` recorded in both install-identity files). Library-soname selection and platform detection are deterministic and identical across arms — no plausible numerics channel.
- lm-eval side: identical version, seeds, concurrency, retries; both arms' servers had equivalent warm-up history (greedy probe + 20-example smoke before the measured run).

Residual asymmetries assessed:
1. KV-cache sizing differed slightly (baseline 53,489 tokens / 19.43 GiB vs PR 52,962 / 19.24 GiB; profiling estimates 0.7828 vs 0.7788) — a **downstream consequence of the PR kernels' own memory footprint**, not an independent variable; with zero preemptions and 6.5× concurrency headroom vs 8 concurrent requests, scheduling was never KV-constrained. Cannot explain a 2/8→1/8 greedy convergence.
2. Baseline's aborted first full attempt (~35 requests + 16-min idle before the measured run, D2) — affects only warm/prefix-cache state; symmetric-noise at most, and both arms' greedy probes (the attribution-critical measurement) ran on freshly-started servers under identical protocol.
3. Batch-composition nondeterminism (the very phenomenon under study) contributes run-to-run noise to GSM8K — which is why the ≈0.15σ deltas are correctly reported as "no material regression observed" rather than as identity.

Nothing besides the PR's kernel diff plausibly explains the greedy convergence (a numerics-order change is required for 2/8→1/8 with convergence onto a baseline-produced ordering, while the byte-identical 512-ctx output across arms shows the rest of the stack unchanged); the tiny GSM8K deltas are within noise under any explanation.

**Frozen-config sanity check:** experiment-config.txt (bfloat16, TP 1, gpu-mem 0.92, max-model-len 8192, port 8000) matches what actually ran in both logs. ✓

---

## Defect register

| ID | Severity | Description | Disposition |
|---|---|---|---|
| D1 | Non-blocking reporting defect | Paired-flip stats mislabeled "strict-match" (actual: flexible-extract values 23/20/1276; true strict = 22/20/1277). Root cause: `07_compare.py` filter-overwrite + dead branch. Present in ab-summary.md, README.md L45, PR_REPLY.md L48. Conclusions unaffected. | Remediated by appended correction notes in `results/ab-summary.md` and `README.md`. **PR_REPLY.md must be corrected by the author before posting** (not modified by reviewer). |
| D2 | Non-blocking transparency gap | Undisclosed aborted first baseline full-GSM8K attempt (02:35:19→~02:37:19, ~35 requests) before the successful 02:53 run; not in README timeline. No data contamination (single results file set, self-consistent, mtime==ctime; server never restarted). | Documented here; no data change needed. |
| D3 | Cosmetic | PR_REPLY server command shows HF repo id; actual runs used the local path of the same repo @ 2b537554 (hash-verified). README records the actual command. | Flagged for author; no change made. |
| D4 | Cosmetic (pre-existing, already remediated) | baseline build.log trailing false-alarm `AssertionError` (lazy op-namespace probe) and install-identity.txt missing dirty-entries line — both carry earlier verifiers' appended explanatory notes; facts re-verified here (dirty=0 both worktrees, serve-time md5s match disk). | Accepted as remediated. |

No blocking defects found.

## Remediation applied by this reviewer

- Appended correction note to `results/ab-summary.md` (derived report) documenting the filter-overwrite bug and the true strict/flexible flip numbers.
- Appended "Correction note" section to `README.md` with the corrected per-example numbers and a pointer that PR_REPLY.md L48 needs the same fix.
- No data files (results_*.json, samples_*.jsonl, greedy JSONs, prompts, logs) were modified; verified their mtime==ctime integrity before writing anything.

## Verdict

The experiment is trustworthy: git provenance exact; the arms differ only by the PR's kernel diff; both arms verifiably served their own build with the target kernel routed; model/tokenizer/prompts/seeds/flags/backends identical; all published aggregates reproduce exactly from raw per-sample data; greedy convergence claims are exactly supported by the hashes; conclusions are worded within what the data supports. The defects found are reporting-level (mislabeled flip stats, undisclosed aborted first attempt, cosmetic command simplification) and do not change any conclusion; two were remediated via clarifying notes, one requires a one-line author fix in PR_REPLY.md before posting.

FINAL VERDICT: PASS WITH NOTES
