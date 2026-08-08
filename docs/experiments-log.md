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

### 2026-08-09 主注意力 OOM 根因 + sub-quadratic 突破（T2V 端到端跑通）

- 目的：让 H3 主注意力（序列长 9326）不再 OOM，跑通 640×384×124 帧 T2V。
- 环境/配置：ComfyUI portable v0.31.0 + torch 2.13.0+xpu，Arc iGPU 12.4GB 共享显存，启动参数 `--lowvram --use-quad-cross-attention`。
- 操作步骤：
  - 首次提交（无 `--lowvram`）：文本编码器 14.2GB 整体加载进 XPU → 报错 39。
  - 加 `--lowvram` 后：文本编码器走 CPU，DiT 部分加载（4520MB 在 XPU，10642MB 卸载）；首次 9326-token 注意力仍 OOM。
  - 读源码定位：`attention_split`（`--use-split-cross-attention`）会一次性物化 r1 = 56×9326×9326×2B ≈ 9.7GB 分数矩阵，12.1GB 显存放不下。
  - 曾改 `attention.py`：steps 上限 64→1024、slice_size 改向上取整（对 split 有效但非根治）。
  - 最终改用 stock 参数 `--use-quad-cross-attention` → 走 `attention_sub_quad`（分块 online softmax，s=9326 时 query_chunk=1024/kv_chunk=9326，峰值块内存约 1GB）。
- 结果：2 步调试工作流（同样 640×384×124 潜在）端到端成功，产出 `ComfyUI\output\minimax_h3_xpu_t2v_00001_.mp4`（1.66MB，含音频）。
- 报错原文：
  - `RuntimeError: level_zero backend failed with error: 39 (UR_RESULT_ERROR_OUT_OF_DEVICE_MEMORY)`
  - `RuntimeError: level_zero backend failed with error: 40 (UR_RESULT_ERROR_OUT_OF_RESOURCES)`（`raise_non_oom` 不识别 error 40，不会自动加 steps 重试）
  - `RuntimeError: level_zero backend failed with error: 20 (UR_RESULT_ERROR_DEVICE_LOST)`（硬 OOM 后的连锁，需重启服务器）
  - `torch.OutOfMemoryError: XPU out of memory. Tried to allocate 9.07 GiB. GPU 0 has a total capacity of 12.11 GiB ...`
- 耗时：2 步调试共 30 分 58 秒（文本编码约 6 分 + 采样 2 步约 18.5 分 ≈ 9.1 分/步 + VAE 解码/存片约 6 分）。
- 结论 / 下一步：sub-quadratic 是 H3 在 12GB iGPU 上的可用注意力路径；42 步全量约 6.4 小时，已通宵执行（prompt_id `00d51eb0`），待核验成片质量与耗时。

---

<!-- 新实验请追加在下方 -->
