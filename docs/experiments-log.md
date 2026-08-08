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

<!-- 新实验请追加在下方 -->
