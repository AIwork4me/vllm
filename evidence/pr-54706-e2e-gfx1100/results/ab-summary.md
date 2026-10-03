# A/B summary — PR #54706 gfx1100 (machine-generated)

- baseline results: `/workspace/validation-54706-e2e/baseline/lm_eval/full/__opt__models__gemma-3-27b-it-w4a16/results_2026-10-03T03-37-15.118605.json`
- PR results:       `/workspace/validation-54706-e2e/patched/lm_eval/full/__opt__models__gemma-3-27b-it-w4a16/results_2026-10-03T04-37-08.582400.json`

## Full GSM8K (lm-eval 0.4.13, local-completions, 5-shot, temperature=0)

| metric | baseline (28c57456) | PR #54706 (16ce8ac8) | delta |
|---|---:|---:|---:|
| exact_match,flexible-extract | 0.8431 | 0.8408 | -0.0023 |
| exact_match,strict-match | 0.8362 | 0.8347 | -0.0015 |
| exact_match_stderr,flexible-extract | 0.0100 | 0.0101 | +0.0001 |
| exact_match_stderr,strict-match | 0.0102 | 0.0102 | +0.0000 |
| sample_len | 1319.0000 | 1319.0000 | +0.0000 |
| evaluated examples | 1319 | 1319 | |

## Fixed-input greedy repeatability (8 runs x 64 tokens, temperature=0)

| context | baseline | PR #54706 |
|---|---:|---:|
| ctx512 | 1/8 distinct | 1/8 distinct |
| ctx8192 | 2/8 distinct | 1/8 distinct |

## Paired per-example comparison (strict-match)

```
correct->wrong    : 22
wrong->correct    : 20
correct->correct  : 1081
wrong->wrong      : 196
```

Flipped doc_ids (first 30): 13: F->T, 20: T->F, 97: F->T, 183: T->F, 214: T->F, 227: T->F, 242: T->F, 322: T->F, 357: F->T, 371: F->T, 392: T->F, 450: T->F, 519: T->F, 552: T->F, 580: T->F, 587: F->T, 629: T->F, 638: T->F, 727: F->T, 798: T->F, 809: F->T, 815: T->F, 832: T->F, 837: T->F, 866: F->T, 916: T->F, 950: T->F, 963: F->T, 979: F->T, 1012: T->F

## Paired per-example comparison (flexible-extract)

```
correct->wrong    : 23
wrong->correct    : 20
correct->correct  : 1089
wrong->wrong      : 187
```

Flipped doc_ids (first 30): 13: F->T, 20: T->F, 97: F->T, 183: T->F, 214: T->F, 227: T->F, 242: T->F, 265: T->F, 322: T->F, 357: F->T, 371: F->T, 392: T->F, 450: T->F, 519: T->F, 552: T->F, 580: T->F, 587: F->T, 638: T->F, 727: F->T, 798: T->F, 809: F->T, 815: T->F, 829: F->T, 832: T->F, 837: T->F, 866: F->T, 916: T->F, 950: T->F, 979: F->T, 1012: T->F

