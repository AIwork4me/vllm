# vLLM PR #54706 gfx1100 端到端验证 — 完整工作报告

**日期：** 2026-10-03（UTC）
**任务：** 响应 PR #54706（[ROCm][RDNA3] Fix W4A16 split-K accuracy and determinism）评审人 `@tjtanaa` 的请求："which model is affected? Please provide the end to end command and end to end lmeval scores for the model."
**状态：** ✅ 全部完成，证据已发布，等待发布 PR 回复

---

## 1. 任务背景

- 问题根源：RDNA3 W4A16 GEMM 内核的 FP32 split-K 部分和经过**过早的 bf16/fp16 收窄 + CAS 原子累加**，导致结果依赖执行顺序（非确定性）。
- 修复思路：FP32 逐 split 部分和 → **固定顺序 FP32 归约** → 最后一次性 bf16/fp16 转换。
- 历史隔离模型：`Muse-Glimmer-30B-INT4`（原始复现者，不重跑全量 lm-eval）。
- 本次正式端到端验证模型：`gemma-3-27b-it-w4a16`（已独立确认走同一受影响内核路径）。
- 本任务**不是**内核开发，而是补齐评审人要求的模型级端到端验收证据。

## 2. 执行时间线（UTC，2026-10-03）

| 时间 | 事件 |
|---|---|
| ~01:00 | 接续前次会话：环境采集、双工作树、模型下载、基线构建已完成并通过 Checkpoint 1-2 验证 |
| 01:22-01:40 | 修正基线健康检查误报；启动并完成 PR 臂构建；确认模型下载完整（28 GB，4/4 分片） |
| 01:28 | 冻结两个定长提示词（ctx512=443 tokens、ctx8192=8123 tokens，SHA256 存档） |
| 01:31-02:25 | 诊断并解决 4 项环境级阻塞问题（详见 INCIDENTS.md #2/#3/#5/#6） |
| 02:22 | 基线臂 editable 重定向完成（serve 时 `.so` md5 `83500bc9…`） |
| 02:28 | 基线服务器就绪（dev538+g28c57456d，~270 s） |
| 02:33 | 基线贪心可重复性测试：ctx512 **1/8**、ctx8192 **2/8**（复现历史非确定性） |
| 02:34 | GSM8K 冒烟测试（20 例，0.85/0.85，管线健康） |
| 02:35-02:37 | 首次全量 GSM8K 尝试被 shell 超时误杀（~35 请求，未产生任何结果文件，已披露） |
| 02:53-03:37 | **基线全量 GSM8K 成功**（1319/1319，43 分 38 秒） |
| 03:40 | 基线服务器干净关闭（VRAM 回落到 28 MB 空闲态） |
| 03:47-03:48 | PR 臂切换并就绪（dev541+g16ce8ac88，serve 时 `.so` md5 `9c51583d…`） |
| 03:50 | PR 贪心测试：ctx512 **1/8**、ctx8192 **1/8** |
| 03:52 | PR 冒烟测试（20 例，0.85/0.85） |
| 03:52-04:37 | **PR 全量 GSM8K 成功**（1319/1319，44 分 30 秒） |
| 04:40 后 | PR 服务器关闭；运行 PR 自带内核确定性测试套件 **54/54 通过**；生成 A/B 对比；四轮独立子代理验证 + 最终对抗性评审；证据分支发布 |

## 3. 实验设计（冻结配置，两臂完全一致）

```
GPU:        1× AMD Radeon Pro W7900D（gfx1100，48 GB），TP=1
dtype:      bfloat16（checkpoint 默认）
服务:       vllm serve --gpu-memory-utilization 0.92 --max-model-len 8192 --port 8000
评测:       lm-eval 0.4.13 local-completions → http://127.0.0.1:8000/v1/completions
任务:       gsm8k（harness 默认 5-shot，temperature=0，无 --limit）
模型:       RedHatAI/gemma-3-27b-it-quantized.w4a16 @ 2b537554（哈希存档）
A/B 隔离:   BASE=28c57456（PR 首提交父提交）vs PR=16ce8ac8（GitHub API 核实的当前 head）
            差异仅为 4 个 csrc/rocm 内核文件 + 1 个测试文件；Python 源码零差异
            共享同一 venv/ROCm/PyTorch/模型文件/提示词/服务参数，仅通过
            pip install -e <worktree> 重定向切换臂
```

## 4. 实测数据（全部可从原始文件复算）

### 4.1 内核路由（两臂均确认）

- 基线 `server.log`：`Using RDNA3W4A16LinearKernel for CompressedTensorsWNA16` + `for mixed-precision linear`
- PR `server.log`：`Using RDNA3W4A16LinearKernel` ×2
- 独立验证者用 `/proc/<pid>/maps` 证明：每个运行中的服务器映射的是**各自臂**编译的 `_rocm_C.abi3.so`；两臂日志中均无竞争内核（Exllama/Marlin/Triton W4A16）出现

### 4.2 定输入贪心可重复性（8 次 × 64 tokens，temperature=0，同一服务器实例）

| 上下文 | 基线 28c57456 | PR 16ce8ac8 |
|---|---:|---:|
| ~448 token 提示 | 1/8 种不同输出 | 1/8 种 |
| ~8128 token 提示 | **2/8 种** | **1/8 种** |

- 基线两种输出的哈希：`ff74c672…`×5、`2b0de610…`×3（首个分歧点在第 66 字符："two **key** historical" vs "two historical"）
- PR 唯一输出 `2b0de610…` **恰好是基线两种可能输出之一** —— 固定顺序归约收敛到既有排序，而非凭空新结果
- ctx512 输出两臂字节级一致（`e8eebe8a…`）

### 4.3 全量 GSM8K（每臂 1319/1319 例）

| 指标 | 基线 | PR #54706 | Δ |
|---|---:|---:|---:|
| exact_match, strict-match | 0.8362 | 0.8347 | −0.0015 |
| exact_match, flexible-extract | 0.8431 | 0.8408 | −0.0023 |
| 标准误（strict/flexible） | 0.0102 / 0.0100 | 0.0102 / 0.0101 | — |

逐例配对（strict-match）：**正确→错误 22，错误→正确 20**，不变 1277（1081 正确 + 196 错误）；
（flexible-extract：23 / 20 / 1276）。差值 ≈ 0.15–0.23 个标准误，翻转移近对称。

### 4.4 PR 自带内核测试套件（PR 臂运行一次）

`tests/kernels/quantization/test_rdna3_w4a16_determinism.py`：**54 通过 / 0 失败**（首次 `-x` 运行曾因 torch.profiler 首次会话空采集抖动中断于 1 项——断言消息为字面量 `set()`，未触及任何数值断言；完整重跑全部通过，已记录于日志）。

## 5. 独立验证与对抗性审查

| 报告 | 范围 | 结论 |
|---|---|---|
| checkpoint-1-2-environment-git.md | 环境 + Git 溯源 | PASS / PASS |
| checkpoint-3-4-5-baseline-model-build-routing.md | 模型资格 + 基线构建 + 路由 | PASS / PASS WITH NOTES（已整改）/ PASS WITH NOTES（已整改） |
| checkpoint-6-11-greedy-lmeval-pr.md | 贪心 A/B + 基线 lm-eval + PR 构建/路由 | PASS（全部六项） |
| final-adversarial-review.md | 13 维度终审（含原始样本复算） | **PASS WITH NOTES**（全部 notes 已整改） |

终审亮点：评审人从原始 samples JSONL 独立复算出全部聚合分数（基线 strict 1103/1319=0.83624、PR 1101/1319=0.83472 等，与 results.json 逐位一致）；发现并促成修复了对比脚本的 filter 串号缺陷（strict 逐例数实为 22/20/1277，而非最初报告的 23/20/1276）；确认结论措辞未超出数据支持范围。

## 6. 过程中的问题（摘要，详见 INCIDENTS.md）

14 项工程事件全部诊断并解决，代表性的有：

1. **ROCm 7.14/7.2.1 库竞争**：vLLM `env_override` 预载 `libtorch_cpu.so` 引发 `libamdhip64.so.7` 符号版本错误 → `vllm_cli.sh` 将 venv 7.14 库置于 `LD_LIBRARY_PATH` 首位。
2. **amdsmi 与 ROCm 运行时无法同进程共存**（本机特性）→ 平台探测失败 → 安装带外的 env 门控 pip 插件仅替代**探测**环节（选中与健康机器完全相同的 `RocmPlatform` 类，不触及任何数值路径）。
3. **cwd 遮蔽**（/root 下仓库目录被当作命名空间包）→ 启动器固定 `cd /workspace`。
4. **工具超时误杀**（首次全量 GSM8K、25 分钟 pip 重定向）→ `setsid nohup … < /dev/null` 全脱离。
5. **依赖对齐**：compressed-tensors 0.13.0 → 两臂 requirements 共同锁定的 0.17.0。
6. **对比脚本 filter 串号**（终审发现）→ 修复为按 (doc_id, filter) 键控并重新生成全部汇总。

所有干预均**两臂完全一致**，且经对抗性审查确认不构成混杂因素。

## 7. 结论（严格限定在证据范围内）

1. `gemma-3-27b-it-w4a16` 是真实受影响模型：在 gfx1100 上其量化 Linear 层路由至 `RDNA3W4A16LinearKernel`，且在 PR 精确父提交上 8192 上下文贪心解码非确定（2/8）。
2. PR #54706 在同一协议下使该生成完全确定（1/8），并收敛到基线可能产生的排序之一。
3. 全量 GSM8K（两臂各 1319 例、服务与评测配置完全一致）**未观察到实质性端到端精度回归**：−0.15 pp（strict）/ −0.23 pp（flexible），≈0.15–0.23 σ，逐例翻转移对称（22↔20）。
4. Muse-Glimmer-30B-INT4 仍为原始模型级复现者；本次按评审人要求以 Gemma 完成标准 lm-eval A/B。PR 的实际作用域是 gfx11/RDNA3 W4A16 内核路径本身。

## 8. 产物与位置

| 产物 | 位置 |
|---|---|
| 证据工作区（68 个文件，27 MB） | `/workspace/validation-54706-e2e/` |
| 证据分支（已推送 @ `c1b67a16`） | [AIwork4me/vllm · evidence/pr-54706-e2e-gfx1100](https://github.com/AIwork4me/vllm/tree/evidence/pr-54706-e2e-gfx1100/evidence/pr-54706-e2e-gfx1100) |
| 评审人回复（定稿待发） | `PR_REPLY.md` |
| 文档导航 | `INDEX.md` |
| 证据清单（含 SHA256） | `results/EVIDENCE_MANIFEST.md` |
| 工程事件日志 | `INCIDENTS.md` |
| Git 工作树 | `/root/wt-e2e-baseline`（28c57456）、`/root/wt-e2e-pr`（16ce8ac8），均 clean |

## 9. 推荐下一步

**立即将 `PR_REPLY.md` 发布为 PR #54706 的评论**（唯一剩余阻塞项；`@JartX` 已表态 done for merge，拖延只增加 main 前移带来的 rebase/重跑风险；继续加实验为负收益）。发布后可顺带确认是否需要 rebase 到最新 main。
