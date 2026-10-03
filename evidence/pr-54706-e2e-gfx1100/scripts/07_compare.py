#!/usr/bin/env python3
"""07_compare.py — strict A/B comparison for PR #54706 gfx1100 validation.

Reads:
  baseline/lm_eval/full/<...>/results_*.json   (found recursively)
  patched/lm_eval/full/<...>/results_*.json
  baseline/determinism/greedy-baseline.json
  patched/determinism/greedy-pr.json
  baseline/lm_eval/full/<...>/samples_gsm8k_*.jsonl
  patched/lm_eval/full/<...>/samples_gsm8k_*.jsonl

Emits results/ab-summary.md with aggregate metrics + paired per-example comparison.
"""
import glob
import json
import os
import sys

ROOT = "/workspace/validation-54706-e2e"


def find_one(pattern):
    hits = sorted(glob.glob(pattern, recursive=True))
    if not hits:
        return None
    return hits[-1]


def load_results(arm):
    p = find_one(f"{ROOT}/{arm}/lm_eval/full/**/results_*.json")
    if not p:
        return None, None
    with open(p) as f:
        return json.load(f), p


def load_samples(arm):
    p = find_one(f"{ROOT}/{arm}/lm_eval/full/**/samples_gsm8k_*.jsonl")
    if not p:
        return {}, None
    out = {}
    with open(p) as f:
        for line in f:
            d = json.loads(line)
            out[(d["doc_id"], d["filter"])] = d["exact_match"]
    return out, p


def metric_rows(rb, rp):
    rows = []
    tb = rb["results"]["gsm8k"]
    tp = rp["results"]["gsm8k"]
    keys = sorted(set(tb.keys()) & set(tp.keys()))
    for k in keys:
        if not isinstance(tb[k], (int, float)):
            continue
        vb, vp = tb[k], tp[k]
        rows.append((k, vb, vp, vp - vb))
    return rows


def main():
    rb, pb = load_results("baseline")
    rp, pp = load_results("patched")
    if not rb or not rp:
        print("missing results.json", pb, pp)
        sys.exit(1)

    lines = []
    lines.append("# A/B summary — PR #54706 gfx1100 (machine-generated)\n")
    lines.append(f"- baseline results: `{pb}`")
    lines.append(f"- PR results:       `{pp}`\n")

    nb = rb["n-samples"]["gsm8k"]["effective"]
    np_ = rp["n-samples"]["gsm8k"]["effective"]
    lines.append("## Full GSM8K (lm-eval 0.4.13, local-completions, 5-shot, temperature=0)\n")
    lines.append("| metric | baseline (28c57456) | PR #54706 (16ce8ac8) | delta |")
    lines.append("|---|---:|---:|---:|")
    for k, vb, vp, d in metric_rows(rb, rp):
        lines.append(f"| {k} | {vb:.4f} | {vp:.4f} | {d:+.4f} |")
    lines.append(f"| evaluated examples | {nb} | {np_} | |")
    delta_em = None
    for k, vb, vp, d in metric_rows(rb, rp):
        if "exact_match,strict-match" in k:
            delta_em = (vb, vp, d)
    lines.append("")

    # greedy
    lines.append("## Fixed-input greedy repeatability (8 runs x 64 tokens, temperature=0)\n")
    lines.append("| context | baseline | PR #54706 |")
    lines.append("|---|---:|---:|")
    for ctx in ["ctx512", "ctx8192"]:
        try:
            with open(f"{ROOT}/baseline/determinism/greedy-baseline.json") as f:
                gb = json.load(f)
            with open(f"{ROOT}/patched/determinism/greedy-pr.json") as f:
                gp = json.load(f)
            lines.append(f"| {ctx} | {gb[ctx]['unique_outputs']}/8 distinct | {gp[ctx]['unique_outputs']}/8 distinct |")
        except Exception as e:
            lines.append(f"| {ctx} | ERROR: {e} | |")
    lines.append("")

    # paired per-example
    sb, sbp = load_samples("baseline")
    sp, spp = load_samples("patched")
    for filt in ("strict-match", "flexible-extract"):
        keys_b = {k for k in sb if k[1] == filt}
        keys_p = {k for k in sp if k[1] == filt}
        if keys_b and keys_b == keys_p:
            b2p = {"correct->wrong": 0, "wrong->correct": 0, "correct->correct": 0, "wrong->wrong": 0}
            flip_examples = []
            for doc_id, _ in sorted(keys_b):
                vb = sb[(doc_id, filt)]
                vp = sp[(doc_id, filt)]
                key = ("correct" if vb else "wrong") + "->" + ("wrong" if not vp else "correct")
                b2p[key] += 1
                if vb != vp and len(flip_examples) < 30:
                    flip_examples.append((doc_id, vb, vp))
            lines.append(f"## Paired per-example comparison ({filt})\n")
            lines.append("```")
            for k, v in b2p.items():
                lines.append(f"{k:18s}: {v}")
            lines.append("```\n")
            if flip_examples:
                lines.append(f"Flipped doc_ids (first 30): "
                             + ", ".join(f"{d}: {'T' if b else 'F'}->{'T' if p else 'F'}" for d, b, p in flip_examples))
                lines.append("")
        else:
            lines.append(f"## Paired per-example comparison ({filt})\nSKIPPED (sample sets differ or missing)\n")

    out = f"{ROOT}/results/ab-summary.md"
    with open(out, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    print("saved:", out)


if __name__ == "__main__":
    main()
