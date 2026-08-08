# 实验记录

> 每次实验：日期 | 目的 | 配置 | 结果 | 报错原文 | 结论 | 下一步。
> 报错必须记录**原文**，方便搜索与复现。

## 模板

### YYYY-MM-DD 实验标题

- 目的：
- 环境/配置：
- 操作步骤：
- 结果：
- 报错原文：
- 耗时：
- 结论 / 下一步：

---

## 实验列表

### 2026-08-08 M0 环境摸底

- 目的：确认这台电脑是否可作为 H3 研究平台。
- 环境/配置：见 [hardware-profile.md](hardware-profile.md)。
- 操作步骤：WMI 采集硬件、检测 nvidia-smi、检查 Python/git/磁盘。
- 结果：
  - CPU Core Ultra 5 125H（14C/18T）✅
  - Arc 核显 7 Xe / 112 EU，PCI Device 7DD5，驱动 32.0.101.6556 ✅
  - 内存 23.4 GiB；磁盘空闲 ~173GB ✅
  - 无 NVIDIA GPU（nvidia-smi 不存在）→ CUDA 路线关闭，确认走 XPU/CPU
  - Python 3.12.0 / git 2.54.0 ✅
  - 发现 Windows 凭据管理器存有 GitHub 凭据（账号 yxtan5022-maker），用于推代码
- 报错原文：无。
- 耗时：约 10 分钟。
- 结论 / 下一步：硬件属"AI PC"级（Arc 核显 + 24GB），值得推进。进入 M1（XPU 环境）。

---

### 2026-08-08 M1 ComfyUI + XPU 基线打通

- 目的：验证 Intel Arc 核显（Meteor Lake 7 Xe）能否在 XPU 后端下跑通 ComfyUI 出图。
- 环境/配置：
  - ComfyUI portable intel 版 v0.31.0（`ComfyUI_windows_portable_intel.7z`，1.6GB）
  - 内嵌 Python 3.13.14 + PyTorch **2.13.0+xpu**（自带 XPU 支持，无需额外装 IPEX）
  - 启动参数：`--windows-standalone-build --use-split-cross-attention`
- 操作步骤：
  1. 下载 portable intel 7z 并解压（7-Zip）
  2. `python -c "import torch; print(torch.xpu.is_available())"` → True
  3. 启动 ComfyUI，验证 `/system_stats` → `xpu:0 Intel(R) Graphics`，VRAM 12.1GB
  4. 下载 SD1.5（`v1-5-pruned-emaonly.safetensors`，4.0GB，hf-mirror 镜像）
  5. 提交 API 工作流：512x512、20 步、euler/normal、cfg 7
- 结果：
  - ✅ 出图成功：`xpu_baseline_00001_.png`（512x512 RGB，417KB，有效图）
  - ⏱ 总耗时 ~97s（含模型加载 + 首轮编译）
  - 📊 VRAM 总 13,007,839,232 字节（12.1GB），核显实际可分配显存
  - 日志确认无 `UR_RESULT_ERROR_OUT_OF_DEVICE_MEMORY`（`--use-split-cross-attention` 生效）
- 报错原文：无。
- 耗时：约 40 分钟（下载 1.6GB 包 + 4GB 模型为主）。
- 结论 / 下一步：
  - **路径 A（XPU）确认可用**，且显存预算提升到 12.1GB（原估 8GB）。
  - M1 完成。下一步 M2：量化研究（INT4/GGUF）+ 模型下载方案。
  - 后续需分离"纯采样耗时"：本回合含加载与编译，需用 KSampler 预热后再测。

---

<!-- 新实验请追加在下方 -->
