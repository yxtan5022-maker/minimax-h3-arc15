# 可行性总报告

> 结论先行：**不是"能不能跑"的问题，而是"最少要等多久、还能不能出片"的问题。**
> 24GB 内存是一道硬墙，但每一道墙都有拆法。

## 1. 硬约束分析

### 1.1 模型体积（官方 ComfyUI 最小组合）

| 文件 | 大小 | 用途 |
|---|---|---|
| minimax_h3_fl2va_pruned_int8_convrot.safetensors | ~21GB | 扩散主干（DiT） |
| qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors | ~15.7GB | 文本编码器 |
| minimax_h3_video_vae_fp16.safetensors | ~5.2GB | 视频 VAE |
| minimax_h3_audio_vae_fp32.safetensors | ~0.6GB | 音频 VAE |
| **合计** | **~42.5GB** | 磁盘占用 |

对照本机：

- 磁盘 173GB：✅ 足够
- 内存 24GB：❌ 放不下（42.5GB ≫ 24GB）
- 核显"显存"：**12.1GB**（M1 实测，torch.xpu，比原估 8GB 高 50%）⚠️ INT8 权重仍放不下，但 INT4 有机会

### 1.2 算力

Arc 核显（7 Xe / 112 EU）≈ RTX 3050 的 1/4 算力，且共享 DDR5 内存带宽（非显存）。
H3 在 RTX 4090 上跑 10 秒视频约 5-8 分钟；在这台机器上按最乐观估计也要 **2-6 小时/镜头**。

### 1.3 结论矩阵

| 约束 | 现状 | 拆法 |
|---|---|---|
| 磁盘 173GB | ✅ 够 | 无需处理 |
| 内存 24GB vs 42.5GB | ⚠️ 有解 | **MiniStack 整栈 ~19GB**（Arc A770 实测）或 W4A8+卸载；页文件兜底 |
| 显存 12.1GB（M1实测） | ⚠️ INT8 不够，INT4 有机会 | XPU 部分层常驻 + CPU offload 其余 |
| 算力 7 Xe | ⚠️ 慢 | 只能接受，或降分辨率(480p) / 缩短时长 |

## 2. 路径排序（按"能出片概率"）

1. **A+B 组合拳（XPU + INT4 量化）**：用 IPEX 把 Arc 核显用起来，同时用社区/自行 INT4 量化
   把权重压到 ~19GB，配合组卸载和页文件。这是最有机会的组合。
2. **B 纯量化 + CPU 推理**：不依赖 XPU，走 CPU 推理。一定能加载，但速度最慢。
3. **C 官方 INT8 + 页文件 + 流式**：42.5GB 靠页文件 + 流式逐层读盘，能做，但慢上加慢，
   仅作为全链路调试基线。

## 3. 研究问题清单（2026-10-06 更新）

- [x] Arc 核显（7 Xe）在 XPU 下能分到多少"显存"？ → **12.1GB**（M1 实测），
      可覆盖 MiniStack DiT（11.4GB）边缘或 W4A8 DiT（12.5GB）大部
- [x] H3 的 DiT 是否有可信的 INT4/GGUF 社区版？ → **有**，见
      [quant-catalog.md](quant-catalog.md)（MiniStack 11.4GB / W4A8 12.5GB / GGUF Q3 15.6GB 起）
- [x] diffusers 的 `enable_group_offload` 对 H3 的支持状态（PR #14355 是否合并）？
      → **已合并**（2026-08-05，modular-only）；group_offload 兼容性待实测
- [ ] Windows 页文件扩展到 64GB 是否稳定？
- [ ] W4A8 的 INT8 GEMM 在 XPU 上是否有 comfy-kitchen 内核？
- [ ] 480p / 5s / 8 步（Turbo LoRA）的最短出片时间预算？

## 4. 相关数据（社区实测参考）

- ComfyUI 官方：832x480、5s、20 步，RTX 3060 12G 上 **<9 分钟**。
- 12GB 显存可行，但依赖充足系统内存 + 快速磁盘（层卸载）。
- 20B 版本（社区降级版）传闻 6G+32G 可玩——需要确认权重出处与许可证。
- MiniStack 作者 eval（Arc A770 16GB）：640×480/124f 25 步 **610s**；turbo 8 步 **~250s**。
  本机 7 Xe ≈ A770 的 1/4~1/5 算力 → 同配置估 **40-80 分钟/镜头**（待实测）。

## 5. Go / No-Go 门槛

见 [roadmap.md](roadmap.md) 决策门槛一节。
