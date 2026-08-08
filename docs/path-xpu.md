# 路径 A：Intel XPU 加速

## 背景

Intel 官方 2026-08-03 宣布对 MiniMax H3 提供 **Day-0 支持**（Intel 新闻室），
官方参考配置为 **32 Xe 核心 + 32GB 显存** 的 Arc 独显。

本机 Arc 核显只有 7 Xe 核心（Meteor Lake），是同一架构的小型化版本，
但支持同一套 XPU 软件栈（IPEX / oneAPI / SYCL）。这条路的本质是：
**把官方在 Arc 上已验证过的软件路径，搬到小得多的核显上重跑一遍。**

## 软件栈

| 层 | 组件 | 状态 |
|---|---|---|
| 驱动 | Intel Graphics Driver 32.0.101.6556 | ✅ 已装 |
| PyTorch + XPU | torch 2.13.0+xpu（便携版内嵌，自带 XPU） | ✅ M1 验证可用 |
| 运行时 | oneAPI / SYCL（随 torch 附带） | ✅ 可用 |
| ComfyUI | portable intel 版 v0.31.0 + `--use-split-cross-attention` | ✅ M1 出图成功 |
| 模型 | Comfy-Org/MiniMax-H3 重打包文件 | ⏳ 待下 |

> **M1 实测（2026-08-08）**：`xpu:0 Intel(R) Graphics`，可用显存 **12.1GB**，
> SD1.5 512x512 20 步出图成功（总 ~97s 含加载）。路径 A 核心已验证。

## 关键问题

1. **"显存"上限**：核显共享内存，Windows 默认分配上限通常为总内存的一半（~12GB 理论值），
   实际可用受驱动/BIOS 限制，先实测 `ipex.xpu.memory_stats`。INT4 后的 DiT ~11GB，
   可能"勉强"驻留，但还需给 VAE/编码器/激活值留空间 → 大概率仍需 CPU offload 配合。
2. **H3 节点在 XPU 后端的兼容性**：ComfyUI 原生节点（MiniMaxH3ImageToVideo /
   MiniMaxH3ReferenceToVideo）在 XPU 上是否可跑未知，需要用小模型先验证整体管线。
3. **SageAttention**：官方提速依赖它，是否有 XPU 等价物未确认。
4. **CUDA 专用算子**：H3 工作流若硬编码 CUDA 算子，需要逐层排查替换。

## 验证步骤（M1）

- [ ] 安装 IPEX（匹配 PyTorch 版本）：`pip install intel-extension-for-pytorch`
- [ ] 自检：
      `python -c "import torch; import intel_extension_for_pytorch as ipex; print(ipex.xpu.get_device_name(0))"`
- [ ] 安装 ComfyUI portable Intel 版
- [ ] 用 SD1.5 / 小图模型验证 XPU 出图，建立速度与显存基线
- [ ] 下载 H3 最小文件集（音频 VAE 0.6GB + 视频 VAE 5.2GB）先验证 VAE 解码
- [ ] 逐步上 DiT，记录每步显存/内存/耗时

## 预期

- 提速：参照 Core Ultra 9 285H（Arc 140T）跑 SD 的社区实测，XPU 约为纯 CPU 的 **9 倍**。
- 但 H3 模型规模远超 SD，整体仍是"小时级出片"。
- 风险：IPEX 对 Meteor Lake 7 Xe 的支持若只覆盖 SD 类模型，H3 的 DiT 需自研适配。

## 决策门槛

- IPEX 装不上或核显不可用 → 放弃路径 A，转 B（纯 CPU 量化推理）。
- H3 节点 XPU 报算子不支持且无法绕开 → 降级为 CPU + XPU 混合（能 offload 多少算多少）。
