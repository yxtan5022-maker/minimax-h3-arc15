# MiniMax H3 无独显笔记本极限部署研究

> 目标：在没有 NVIDIA 独显、只有 Intel Arc 核显的轻薄本上，把 MiniMax H3（开源全模态视频生成模型）跑起来。

**当前状态**：🔬 研究中（M0 环境摸底已完成，M1 准备中）

## 为什么做这个项目

MiniMax H3 是 2026-07-31 开源的全模态视频生成模型（33.1B 参数），官方推荐的本地部署配置是
NVIDIA RTX 3060 12G + 32GB 内存起步。但我们这台机器只有：

- **CPU**: Intel Core Ultra 5 125H（Meteor Lake，14C/18T）
- **GPU**: Intel Arc 核显（7 Xe 核心 / 112 EU，支持 XPU）
- **内存**: 24GB
- **磁盘**: ~173GB 可用

官方最小模型组合就要 **42.5GB**（INT8 量化 + NVFP4 编码器），内存完全不够。但——
Intel 官方已宣布对 H3 提供 **Day-0 支持**（2026-08-03，Intel 新闻室）。这台笔记本的 Arc 核显
和官方参考配置（32 Xe 核心 / 32GB 显存）是**同一架构**，只是规模小。

所以核心课题是：

> 用 **量化 + XPU 加速 + CPU/磁盘卸载 + 流式加载** 的组合，把模型硬塞进 24GB 内存跑出视频片段。
> 哪怕每秒视频要跑几小时，只要能"出片"，研究就成立。

## 硬件档案

| 项目 | 数值 |
|---|---|
| 机型 | HP Laptop 15-fd1xxx |
| CPU | Intel Core Ultra 5 125H（4P+8E+2LPE，14C/18T） |
| GPU | Intel Arc 核显，7 Xe 核心 / 112 EU，PCI Device 7DD5 |
| 内存 | 24GB（23.4 GiB） |
| 磁盘 | 约 173GB 可用 |
| 系统 | Windows / PowerShell 5.1 |
| 工具链 | Python 3.12.0，git 2.54.0 |

详细报告：[docs/hardware-profile.md](docs/hardware-profile.md)

## 三大研究路径

| 路径 | 核心思路 | 可行性 | 研究文档 |
|---|---|---|---|
| A. Intel XPU 加速 | IPEX + ComfyUI XPU 后端，吃满 Arc 核显 | 中 | [path-xpu.md](docs/path-xpu.md) |
| B. 激进量化 | INT4/GGUF 社区量化，把权重压到 <24GB | 中 | [path-quantization.md](docs/path-quantization.md) |
| C. CPU/磁盘卸载 | diffusers 组卸载 + 页面文件 + 流式 mmap | 低（可行但极慢） | [path-cpu-offload.md](docs/path-cpu-offload.md) |

- 可行性总报告：[docs/feasibility.md](docs/feasibility.md)
- 研究路线图：[docs/roadmap.md](docs/roadmap.md)
- 实验记录：[docs/experiments-log.md](docs/experiments-log.md)

## 运行环境检测

```powershell
powershell -ExecutionPolicy Bypass -File scripts/env-check.ps1
```

## 许可

项目代码按 MIT 许可（见 LICENSE）。注意：MiniMax H3 模型权重受其社区许可协议约束
（非商业免费；年收入低于 2000 万美元的组织可商用但需署名）。
