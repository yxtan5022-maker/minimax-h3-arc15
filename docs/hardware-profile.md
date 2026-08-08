# 硬件与环境档案

> M0 基线快照，由 `scripts/env-check.ps1` 采集，可随时重跑更新。

## 快照（2026-08-08）

| 项目 | 数值 |
|---|---|
| 制造/型号 | HP / HP Laptop 15-fd1xxx |
| 操作系统 | Windows |
| PowerShell | 5.1 |
| CPU | Intel Core Ultra 5 125H（4P + 8E + 2LPE） |
| 物理核 / 线程 | 14 核 / 18 线程 |
| GPU | Intel Arc 核显（7 Xe 核心 / 112 EU），PCI\VEN_8086&DEV_7DD5 |
| GPU 驱动 | 32.0.101.6556（Intel Corporation） |
| XPU 可用显存 | **13,007,839,232 字节 ≈ 12.1GB**（M1 实测，torch.xpu） |
| 内存 | 25,158,078,464 字节 ≈ 23.4 GiB |
| 显示 | 1920x1080 |
| 磁盘 C: | 已用 ~314GB / 空闲 ~161GB（总计 ~475GB） |
| Python | 3.12.0 |
| git | 2.54.0.windows.1 |
| nvidia-smi | 不存在（无 CUDA 路线，已确认） |

## 对 H3 的意义

- **Arc 核显（7 Xe）**：Intel Day-0 支持 H3 的是 Arc 架构独显（32 Xe / 32GB）。
  本机为同架构小型版，走 **XPU / IPEX** 软件栈，理论上可复用同一套推理路径。
- **核显显存**：共享系统内存，默认分配上限通常为总内存的 1/2 左右，可在 BIOS 调整。
  实际可用"显存"约 8GB 量级，远小于 INT8 权重（42.5GB），必须依赖量化 + 卸载。
- **24GB 内存**：INT4 量化后 ~19GB，可能勉强装入，仍建议配合页文件兜底。
- **磁盘 NVMe**：173GB 足够下载（模型 ~42.5GB + 冗余），且流式加载依赖其吞吐。

## 重新采集

```powershell
powershell -ExecutionPolicy Bypass -File scripts/env-check.ps1
```

## 变更记录

- 2026-08-08：首次建档（M0）。
