#!/usr/bin/env python3
"""Fixed-input greedy repeatability probe against a running vLLM server.

Protocol (identical for both A/B arms):
  - one server instance, no restart between calls
  - 8 sequential identical completions per context depth
  - temperature=0 (greedy), max_tokens=64, seed=1234
  - prompt bytes come from the shared frozen prompt files (never re-generated)

Usage: greedy_probe.py <arm-label> <outdir>
"""
import hashlib
import json
import sys
import time
import urllib.request

BASE_URL = "http://127.0.0.1:8000/v1/completions"
MODEL = "/opt/models/gemma-3-27b-it-w4a16"
RUNS = 8
MAX_TOKENS = 64

PROMPTS = {
    "ctx512": "/workspace/validation-54706-e2e/results/prompts/ctx512.txt",
    "ctx8192": "/workspace/validation-54706-e2e/results/prompts/ctx8192.txt",
}


def complete(prompt: str):
    body = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "temperature": 0.0,
        "max_tokens": MAX_TOKENS,
        "seed": 1234,
        "logprobs": 1,
    }).encode()
    req = urllib.request.Request(
        BASE_URL, data=body,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read())


def first_diff(a: str, b: str):
    n = min(len(a), len(b))
    for i in range(n):
        if a[i] != b[i]:
            return i
    return n if len(a) != len(b) else -1


def main():
    arm, outdir = sys.argv[1], sys.argv[2]
    results = {}
    for ctx, path in PROMPTS.items():
        prompt = open(path).read()
        runs = []
        for i in range(RUNS):
            t0 = time.time()
            r = complete(prompt)
            dt = time.time() - t0
            c = r["choices"][0]
            toks = None
            if r["choices"][0].get("logprobs") and r["choices"][0]["logprobs"].get("tokens"):
                toks = r["choices"][0]["logprobs"]["tokens"]
            runs.append({
                "run": i,
                "text": c["text"],
                "sha256": hashlib.sha256(c["text"].encode()).hexdigest(),
                "finish_reason": c.get("finish_reason"),
                "completion_tokens": c.get("completion_tokens", r["usage"].get("completion_tokens")),
                "token_strings_sha256": hashlib.sha256(json.dumps(toks).encode()).hexdigest() if toks else None,
                "wall_s": round(dt, 2),
            })
            print(f"[{arm}/{ctx}] run {i}: sha={runs[-1]['sha256'][:16]} tok={runs[-1]['completion_tokens']} ({dt:.1f}s)", flush=True)
        hashes = [x["sha256"] for x in runs]
        uniq = sorted(set(hashes))
        # first divergence relative to run 0, in completion text
        divs = [first_diff(runs[0]["text"], x["text"]) for x in runs]
        results[ctx] = {
            "arm": arm,
            "prompt_file": path,
            "prompt_sha256": hashlib.sha256(open(path, "rb").read()).hexdigest(),
            "runs": runs,
            "unique_outputs": len(uniq),
            "total_runs": RUNS,
            "distinct_hashes": uniq,
            "first_divergence_char_vs_run0": divs,
        }
        print(f"[{arm}/{ctx}] RESULT: {len(uniq)} distinct / {RUNS}", flush=True)
    out = f"{outdir}/greedy-{arm}.json"
    with open(out, "w") as f:
        json.dump(results, f, indent=2)
    print(json.dumps({k: {"unique": v["unique_outputs"], "of": v["total_runs"]} for k, v in results.items()}))
    print("saved:", out)


if __name__ == "__main__":
    main()
