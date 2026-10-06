# 路径 B：激进量化（INT4 / GGUF）

## 背景

H3 扩散主干 33.1B 参数（含 13B AdaLN 分支），文本编码器 Qwen3-VL-32B。
官方 INT8 + NVFP4 最小组合约 42.5GB，远超 24GB 内存，必须继续压缩。

## 体积预算表（2026-10-06 实测值）

| 量化档 | DiT | 文本编码器 | VAE | 合计 | 能否进 24GB |
|---|---|---|---|---|---|
| INT8 (pruned) 官方 | 21.0GB | 15.7GB (NVFP4 AWQ 27.1GB) | 5.8GB | ~42.5GB | ❌ |
| W4A8 ConvRot（Winnougan） | 12.54GB | 15.7GB (int4 版 14.2GB) | 5.8GB | ~28.8GB | ❌ 需卸载 |
| GGUF Q4_0（Abiray） | 18.6GB | 14.6GB (Q4_K_M) | 5.8GB | ~39GB | ❌ |
| GGUF Q3_K_M（Abiray） | 15.6GB | 14.6GB (Q4_K_M) | 5.8GB | ~36GB | ❌ |
| **MiniStack**（Arc A770 验证） | 11.4GB | **2.5GB + 0.13GB 适配器** | 5.2GB | **~19.2GB** | ✅ 边缘可行 |

社区动态（2026-08）：开源当天（8-03）四个社区量化仓库上线，两个月（至 10 月）已成熟：

- **W4A8 ConvRot**（Winnougan）：INT4 权重 + INT8 GEMM，pruned DiT 12.54 GB、
  量化 TE 14-16 GB。`asym_w4a8_int8` 已并入 **ComfyUI v0.31.0 主线**（PR #15308），
  本机版本原生支持。
- **GGUF**：Abiray（Q3-Q8 全档 + 量化 TE，8 万+/月下载）与 joeygambino（纯经典档 +
  一等 `minimax_h3` arch）两大来源；均走 ComfyUI-GGUF + arch 补丁。
- **MiniStack**（woodfireind）：**在 Intel Arc A770 16GB 上开发验证**的精简栈——
  AdaLN 剪枝 DiT Q4_K_M 11.38 GB + 蒸馏 4B 学生 TE 2.5 GB + 视频 VAE ≈ **19 GB**，
  公布全量 SHA-256；代价是无音频、学生 TE 纯文本（仅 T2V）。
- **Turbo LoRA**（larryvrh，Apache-2.0）：采样 20+ 步 → 4-8 步，最大提速杠杆。
- 假文件/误标风险仍在：K-quant 命名争议与 arch 兼容矩阵见
  [quant-catalog.md](quant-catalog.md) §3。下载后必须 SHA-256 校验。

详细文件清单、SHA-256 与选型矩阵：[quant-catalog.md](quant-catalog.md)。

## 关键问题

1. 量化质量：INT4 DiT 出片是否还能看？AdaLN 分支是否特别敏感？
2. 编码器量化到 INT4 后指令遵循是否崩？
3. 加载路径：✅ 已明朗——ComfyUI v0.31.0 原生支持 `asym_w4a8_int8`（W4A8 safetensors），
   GGUF 走 ComfyUI-GGUF（注意各仓库 arch 标记不同）；diffusers 侧 H3 已合并
   （PR #14355，modular-only），但 ComfyUI 路线更贴合本机。
4. 24GB 内存 + ~22GB 权重：操作系统 + 运行时 + 激活值余量极小 → 大概率仍需页文件 + 流式兜底。

## 验证步骤（M2）

- [x] 收集可信社区量化版本清单（HF tag 搜索：minimax-h3 / gguf / int4），校验来源
      → 完成，见 [quant-catalog.md](quant-catalog.md)
- [x] 若无可信版，用 torchao 将 `pruned_int8_convrot` 自行量化到 INT4
      → 不需要：社区已有 Arc 验证过的 MiniStack 与 W4A8 两条线
- [ ] 下载 MiniStack（`scripts/download-h3-models.ps1 -Set ministack`）并 SHA-256 校验
- [ ] 装 ComfyUI-GGUF + `h3_small_te` 节点，加载测试：能否在 24GB 内完成 load 而不 OOM（先不推理）
- [ ] 质量对比：INT8 vs W4A8 vs MiniStack 同 prompt 出片对比
- [ ] 验证 XPU 上 W4A8 的 INT8 GEMM 是否有内核（无则回退 dequant 路径测速）
- [ ] 叠加 Turbo LoRA（v4-600，6-8 步）测端到端耗时
- [ ] 记录最小可行组合的体积/加载时间/首 token 时间

## 预期

- INT4 是唯一可能"全内存常驻"的方案，但大概率仍需与路径 C（页文件/流式）组合。
- 这是本项目最可能"出片"的关键路径，值得投入最多精力。
