# Index — PR #54706 gfx1100 end-to-end validation evidence

Everything in this tree. Read order for a reviewer: README → results/ab-summary.md →
verification/final-adversarial-review.md → raw files as needed.

## Top-level documents

| Document | Purpose |
|---|---|
| [README.md](README.md) | Main evidence document: environment, routing, GSM8K A/B, greedy A/B, commands, timeline, conclusions |
| [WORK_REPORT.md](WORK_REPORT.md) | Complete work report (Chinese): mission, timeline, measured data, incidents summary, conclusions, recommended next step |
| [PR_REPLY.md](PR_REPLY.md) | Reviewer-ready PR comment (final, with evidence link) |
| [INDEX.md](INDEX.md) | This navigation file |
| [INCIDENTS.md](INCIDENTS.md) | All 14 engineering incidents: symptom → root cause → resolution; attribution integrity statement |

## Results

| Document | Purpose |
|---|---|
| [results/revision-rationale.md](results/revision-rationale.md) | Why BASE_SHA=28c57456 is the correct control |
| [results/experiment-config.txt](results/experiment-config.txt) | Frozen configuration identical for both arms |
| [results/ab-summary.md](results/ab-summary.md) | Machine-generated A/B comparison incl. paired per-example flips (both filters) |
| [results/EVIDENCE_MANIFEST.md](results/EVIDENCE_MANIFEST.md) | Claim → file mapping with sha256 prefixes and sizes |
| [results/prompts/](results/prompts) | Frozen greedy prompts (byte-identical across arms) |

## Per-arm evidence

- `baseline/` — build.log, health-check.txt, install-identity.txt, server.log, routing/,
  determinism/greedy-baseline.json, lm_eval/{smoke,full}/, final-gpu-state.txt
- `patched/` — build/, install-identity.txt, server.log, routing.txt,
  determinism/greedy-pr.json, lm_eval/{smoke,full}/, pr-determinism-testsuite.log,
  final-gpu-state.txt, serve-arm.log

## Environment

- `environment/` — raw captures (00–04), model-hashes.txt, download logs,
  [ENVIRONMENT.md](environment/ENVIRONMENT.md) (markdown summary)

## Verification (independent adversarial subagents)

- [verification/checkpoint-1-2-environment-git.md](verification/checkpoint-1-2-environment-git.md) — PASS / PASS
- [verification/checkpoint-3-4-5-baseline-model-build-routing.md](verification/checkpoint-3-4-5-baseline-model-build-routing.md) — PASS / PASS WITH NOTES (remediated)
- [verification/checkpoint-6-11-greedy-lmeval-pr.md](verification/checkpoint-6-11-greedy-lmeval-pr.md) — PASS
- [verification/final-adversarial-review.md](verification/final-adversarial-review.md) — PASS WITH NOTES (all notes remediated)

## Scripts (complete reproduction)

`scripts/00_capture_env.sh` → `01_build_baseline.sh` → `02_baseline_greedy.sh` →
`03_baseline_gsm8k.sh` → `04_build_pr.sh` → `05_pr_greedy.sh` → `06_pr_gsm8k.sh` →
`07_compare.py`; helpers: `serve_arm.sh` (arm switch + serve + routing capture),
`run_gsm8k.sh` (lm-eval invocation), `greedy_probe.py` (fixed-input greedy client),
`vllm_cli.sh` (box-quirk launcher, identical for both arms).

## Published location

Branch `evidence/pr-54706-e2e-gfx1100` in the AIwork4me/vllm fork —
<https://github.com/AIwork4me/vllm/tree/evidence/pr-54706-e2e-gfx1100/evidence/pr-54706-e2e-gfx1100>
