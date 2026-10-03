# Evidence manifest — PR #54706 gfx1100 validation

Every claim in README.md maps to at least one file below. SHA256 prefixes (first 16 hex)
computed 2026-10-03 after final corrections; sizes in bytes. Raw per-sample JSONL files
(12.4 MB each) are listed separately — they are the ground truth for all aggregates.

## Claims → evidence

| Claim | Primary evidence | sha256-16 | size |
|---|---|---|---|
| Top-level narrative, all tables, conclusions | README.md | 0aae3d839386e266 | 9307 |
| Reviewer-ready reply (ready to post) | PR_REPLY.md | cb921ee54272509d | 2975 |
| BASE/PR SHA choice justification | results/revision-rationale.md | 3e8168451ace3e8f | 2256 |
| Frozen common experiment configuration | results/experiment-config.txt | 8ccbc57cc2024177 | 3028 |
| Machine-generated A/B summary (post-correction) | results/ab-summary.md | b35d69a5f1fd4231 | 2089 |
| Frozen greedy prompt (512) — 443 tokens | results/prompts/ctx512.txt | 0d7d2e87fd294271 | 2362 |
| Frozen greedy prompt (8192) — 8123 tokens | results/prompts/ctx8192.txt | e95829f96b616a54 | 43141 |
| Baseline arm identity at serve time (HEAD, .so md5 83500bc9…) | baseline/install-identity.txt | 6789b644892c59bf | 470 |
| Baseline runtime kernel routing (RDNA3W4A16LinearKernel) + engine line | baseline/routing/routing-summary.txt (from baseline/server.log) | 25e1fd7511b3fc78 | 5903 |
| Baseline greedy raw runs (1/8 @512, 2/8 @8192, texts+hashes) | baseline/determinism/greedy-baseline.json | 1310bc2d641b629d | 11535 |
| Baseline full GSM8K aggregates (1319 eff., strict 0.83624, flex 0.84306) | baseline/lm_eval/full/…/results_2026-10-03T03-37-15.118605.json | 6bf168a96922f056 | 9323 |
| Baseline server full log (single engine init, no restart in window) | baseline/server.log | 126ef58657374d27 | 218177 |
| PR arm identity at serve time (HEAD, .so md5 9c51583d…) | patched/install-identity.txt | 1617a8c94a08c54d | 303 |
| PR runtime kernel routing | patched/routing.txt (from patched/server.log) | 7cfefe95188831bf | 157 |
| PR greedy raw runs (1/8, 1/8; ctx8192 hash ∈ baseline's) | patched/determinism/greedy-pr.json | d7442cb37b6877d3 | 11432 |
| PR full GSM8K aggregates (1319 eff., strict 0.83472, flex 0.84079) | patched/lm_eval/full/…/results_2026-10-03T04-37-08.582400.json | eaf4aa2973853c5d | 9323 |
| PR server full log | patched/server.log | 80a481c329ecde1f | 213525 |
| PR kernel test suite 54/54 (incl. first-run profiler flake note) | patched/pr-determinism-testsuite.log | a15becf83cc73281 | 1745 |
| Model identity (all shard/config/tokenizer sha256) | environment/model-hashes.txt | 7626f75442cb149c | 11911 |
| Independent verification: env + git | verification/checkpoint-1-2-environment-git.md | b3f442eadcf7d422 | 10906 |
| Independent verification: model/build/routing | verification/checkpoint-3-4-5-baseline-model-build-routing.md | 4801021ebaf54fd4 | 2233 |
| Independent verification: greedy/lm-eval/PR | verification/checkpoint-6-11-greedy-lmeval-pr.md | 19ef8bf33dded109 | 2342 |
| Final adversarial review (13 dimensions, PASS WITH NOTES) | verification/final-adversarial-review.md | 53d053c28bbcea68 | 17794 |

## Ground-truth per-sample files (large, included on the evidence branch)

| File | Content |
|---|---|
| baseline/lm_eval/full/…/samples_gsm8k_2026-10-03T03-37-15.118605.jsonl | 2638 lines = 1319 docs × 2 filters; per-doc exact_match under `filter` field — recomputes both aggregates exactly |
| patched/lm_eval/full/…/samples_gsm8k_2026-10-03T04-37-08.582400.jsonl | same structure, PR arm; enables the paired 22/20 (strict) and 23/20 (flexible) flip analysis |

## Build evidence

| File | Content |
|---|---|
| baseline/build.log | clean build log of dev538+g28c57456d + false-alarm note (INCIDENTS.md #1) + .so rebuild note |
| baseline/health-check.txt | corrected health check PASS (ops present) |
| patched/build/build.log | clean build log of dev541+g16ce8ac88, HEALTH CHECK PASS |
| patched/serve-arm.log | PR arm re-point + serve + readiness transcript |

## Reproduction

All commands are in scripts/ (00–07 plus serve_arm.sh / run_gsm8k.sh / greedy_probe.py /
vllm_cli.sh). A reviewer can reconstruct the entire experiment from those files plus
results/experiment-config.txt. Environment quirks and their identical-arm handling are in
INCIDENTS.md.
