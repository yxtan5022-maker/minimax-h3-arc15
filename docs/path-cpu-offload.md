# 路径 C：CPU / 磁盘卸载 + 流式加载

## 背景

即使量化到 INT4（~22GB），24GB 内存也紧张。把权重放磁盘（NVMe），按需 mmap 加载，
推理时逐层/逐组交换。PyTorch 侧对应 `enable_auto_cpu_offload` / `enable_group_offload`。

## 内存账单（INT4 情景）

| 项目 | 大小 |
|---|---|
| DiT (INT4) | ~11GB |
| 文本编码器 (INT4) | ~8GB |
| VAE | ~3GB |
| 激活值 / 临时缓冲 | 2-4GB |
| 操作系统 + Python 运行时 | ~4GB |
| **合计** | **~28GB（>24GB，仍需页文件 ~8GB 兜底）** |

## 策略

1. **页文件扩展**：Windows 页面文件设到 64GB（可调），让超额部分落盘。
2. **流式加载**：mmap 加载 safetensors，避免一次性读进 RAM。
3. **组卸载**：DiT block / 层 常驻 CPU，按需上 XPU（与路径 A 组合）或纯 CPU。
4. **分辨率杠杆**：megapixels 0.4 → 864x480 预览档，把激活值压到最低。

## 关键问题

- diffusers 对 H3 的集成在 **PR #14355**（Draft 状态），`enable_group_offload` 是否可用需确认。
- 磁盘 IO 是瓶颈：NVMe 顺序读 ~3GB/s，每交换 11GB ≈ 4s，可接受；但页文件交换频繁会"假死"。
- ComfyUI 的动态显存卸载（layered offload）在非 CUDA 后端是否生效需实测。

## 验证步骤（M3）

- [ ] 确认 diffusers PR 状态；需要则安装对应 git 版本
- [ ] 页文件 → 64GB，重启生效
- [ ] 先用最小文件集（VAE + 编码器）验证加载管线
- [ ] 全量 FL2VA 加载，记录加载耗时与峰值内存
- [ ] 用 1 步（step=1）最低分辨率试跑，验证能出片

## 预期

- 这是"兜底路径"：必然能加载，速度最慢，但它是 H3 官方支持的 diffusers 方式，
  错误信息最规范，适合做全链路调试基线。
- 与路径 A/B 组合后，它是"保证能跑"的保险丝。
