# H3 社区量化目录（2026-10-06 核验）

> 全部文件大小经 Hugging Face API 核验；SHA-256 来自发布者 README 或 HF LFS etag。
> 本机预算：**内存 23.4 GiB / XPU 可用 12.1 GB / 磁盘 ~160 GB**。
> 仅列 FL2VA（T2V/首末帧）所需文件；Ref2VA 多数仓库有同名对应文件。

## 1. 候选栈对比（按"能否进 24GB"排序）

| 方案 | DiT | 文本编码器 | VAE | 合计 | 进 24GB | 备注 |
|---|---|---|---|---|---|---|
| **MiniStack**（woodfireind） | pruned Q4_K_M GGUF **11.38 GB** | 蒸馏 4B 学生 Q4_K_M **2.50 GB** + 适配器 0.13 GB | 视频 VAE fp16 5.21 GB | **~19.2 GB** | ✅ 边缘可行 | **Arc A770 16GB 上开发验证**；无音频；学生 TE 纯文本（仅 T2V） |
| **W4A8 ConvRot**（Winnougan） | pruned W4A8 **12.54 GB** | W4A8 **15.70 GB**（int4_convrot 版 14.17 GB） | 同上 +0.61 GB 音频 VAE | ~28.8 GB | ❌ 需卸载 | 保留完整教师 TE + 音频；v0.31.0 原生支持 |
| **Abiray GGUF** | Q3_K_M 15.57 GB / Q4_0 18.64 GB | Q4_K_M 14.58 GB | 同上 | ~30-34 GB | ❌ 需流式卸载 | 下载量最大（8 万+/月）；K 档命名有争议（见 §3） |
| **joeygambino GGUF** | Q4_0 19.86 GB / Q5_1 25.92 GB | 用 Comfy-Org 原版 | 同上 | ~20-26 GB（仅 DiT） | ❌ | 纯经典量化；Q3mix 17.3 GB 待发 |
| **Abiray ConvRot** | mixed int4/int8 15.90 GB / nvfp4 12.53 GB | — | 同上 | — | ❌ | nvfp4 面向 Blackwell，XPU 无对应内核 |

## 2. 文件清单与 SHA-256

### 2.1 MiniStack — `woodfireind/MiniMax-H3-GGUF-MiniStack`（推荐首选）

| 文件 | 大小 | SHA-256（发布者公布） |
|---|---|---|
| `diffusion_models/MiniMax-H3-FL2VA-pruned-Q4_K_M.gguf` | 11.38 GB | `51783047a6be43c9fcedc3c0a1746480dac867839ba1ad2e1c698da9d7058201` |
| `text_encoders/qwen3vl-4b-h3student-Q4_K_M.gguf` | 2.50 GB | `7ff66b1541723fc4c4c3f2cba75f72740fad43276ab1d6d564379e591a2e74e5` |
| `text_encoders/te_adapter_v1.safetensors` | 0.13 GB | `ef2060e1a277820416d895812dd580234d3c2760af8e6d203b38e3df2e0952b0` |
| `text_encoders/h3_tokenizer/*`（4 个文件） | ~11 MB | 见发布者 README |
| `vae/minimax_h3_video_vae_fp16.safetensors` | 5.21 GB | `7c1f131492e7eddacaac9069a61b81bdd39de5cc96561e677c5eab1cdce5e522` |

- 还需 `custom_nodes/h3_small_te/`（随仓库提供：H3SmallTELoader / H3SmallTextEncoder）
  和 **ComfyUI-GGUF** 节点包（DiT 按 arch `wan` 归档，学生 TE 为 `qwen3vl`）。
- A770 实测（作者 eval）：640×480/124f，25 步 610 s；turbo LoRA 8 步 ~250 s。
  本机 7 Xe 约为 A770 的 1/4~1/5 算力，**同配置估 40-80 分钟/镜头**（待实测）。
- 取舍：无音频输出；学生 TE 无视觉路径（I2V/FL2V 需换回 32B 教师 TE）；
  适配器保真 val_cos ≈ 0.93（剪辑结构保留，小细节会糊）。

### 2.2 W4A8 ConvRot — `Winnougan/MiniMax-H3-INT4_Convrot_ComfyUI`（全功能备选）

| 文件 | 大小 | SHA-256（LFS etag） |
|---|---|---|
| `minimax_h3_fl2va_pruned-w4a8_convrot_pruned.safetensors` | 12.54 GB | `8b624de0ab7554bb507c4486093d4c93e0bf2eb2a40c2382f26eb0af7cd97407` |
| `minimax_h3_ref2va_pruned-w4a8_convrot_pruned.safetensors` | 12.54 GB | `16be87247dff1f49c7141d6bcde4c0465fc254128e2de60e34aebc744a8177df` |
| `qwen3vl_32b_minimax_h3-w4a8_convrot.safetensors` | 15.70 GB | `808e3b351e71e3dd2444e2cdd6accc701e5b40254ede13d481936e6332c7a0e2` |
| `qwen3vl_32b_minimax_h3-int4_convrot.safetensors` | 14.17 GB | `a97a557136057a8bcf6f2459b0875aeee3e8274408bd6616b669b41caefdb48d` |

- `asym_w4a8_int8` 支持已在 **ComfyUI v0.31.0**（2026-08-08 发布，PR #15308）——
  **本机便携版 v0.31.0 原生支持，无需升级、无需自定义节点**。
- W4A8 = INT4 权重 + INT8 GEMM（ConvRot 旋转 + Lloyd-Max 码本 + FP8 组缩放）。
  **风险**：INT8 GEMM 走 comfy-kitchen 内核，XPU 上是否有对应实现未验证；
  若无则可能回退到 dequant 路径（更慢但应能用）。→ M3 验证项。
- 总权重 ~28 GB > 内存 → 沿用已验证的 `--lowvram` CPU 卸载组合。

### 2.3 Abiray GGUF — `Abiray/MiniMax-H3-GGUF`（社区主流，备选）

| 文件 | 大小 | SHA-256（LFS etag） |
|---|---|---|
| `unet/MiniMax-H3-FL2VA-Q3_K_M.gguf` | 15.57 GB | `5cf5285fbedf870ce4e74b49cd3d14b8d508a59ea5be8fa8699a4d4f728c41df` |
| `unet/MiniMax-H3-FL2VA-Q4_0.gguf` | 18.64 GB | `90f4dabdf0f3f8fc80c01bfb150789e92b14ccc92953d8d3c0006b7f516cef1b` |
| `text_encoders/qwen3vl_32b_minimax_h3-Q4_K_M.gguf` | 14.58 GB | `ccfaa8d786cafce211cb4cd3ab69b64a5240f124eb237d62c0178e58d3ba5121` |

- 档位齐全（Q3_K_S → Q8_0，15.6-36 GB），自带 FL2V/Ref2V 工作流 JSON。
- 需 ComfyUI-GGUF；H3 的 GGUF 支持需要 arch 补丁（见 §3）。

### 2.4 加速件 — `larryvrh/MiniMax-H3-Turbo-Lora`（强烈推荐配套）

| 文件 | 大小 | SHA-256（LFS etag） |
|---|---|---|
| `minimax_h3_turbo_v4_step600_ema.safetensors`（推荐） | 0.78 GB | `5f3a626cd72c93a8b9318d6760c510bc5092d2ab13aaba1f932c5bab07a416d3` |
| `minimax_h3_turbo_4step_ema.safetensors`（v1，备选） | 0.78 GB | `8d645b67e606874e9179b277cea721c1f1e75830532fcc2206e23353cb33edc5` |

- 采样从 ~20-42 步降到 **4-8 步**（甜点 6-8 步，>8 步反而过锐化）。对本机是最大提速杠杆。
- Apache-2.0；20 万+ 下载。注意：其 `adaln_proj` 目标在 **pruned** 检查点上悬空
  （MiniStack/W4A8 pruned 都会静默跳过这部分）——需实测对效果影响。

## 3. 避坑记录

- **K-quant 命名争议**：H3 hidden width 2688，K-quant 要求行数 256 整除（2688 % 256 = 128）。
  joeygambino 指出标着 `Q*_K_*` 的 H3 文件内部实际落成了经典量化（名不副实）。
  Abiray 的 K 档文件确存在（且用量大）——**不代表是假文件，但不应按 K 档质量预期**。
  MiniStack 的 `Q4_K_M` 是另一条线：arch `wan` + 自建量化器，53 个 fp32/fp16 高精度岛。
- **arch 兼容**：三个 GGUF 系仓库用了不同 arch 标记（`minimax_h3` / `wan` / `qwen3vl`），
  对应需要不同版本的 ComfyUI-GGUF / 节点补丁，混用会加载失败——**同一套文件尽量同一来源**。
- **官方文件来源**：MiniMax 与 Comfy-Org 都没有官方 GGUF；所有 GGUF 均为社区转换。
  下载后务必用 §2 的 SHA-256 校验（`scripts/download-h3-models.ps1 -VerifyOnly`）。

## 4. 选型结论（本机）

1. **先上 MiniStack**：唯一在 Arc 系 GPU 实测过的整栈；~19 GB 是唯一能"接近装进 24GB"
   的方案；带全量 SHA-256。代价：无音频、仅 T2V、学生 TE 保真 0.93。
2. **W4A8 做对照组**：同 prompt 同种子对比 INT8 基线 vs W4A8 vs MiniStack 的画质/速度，
   验证 XPU 上 W4A8 内核是否可用。
3. **GGUF 纯档（Abiray/joeygambino）留作回退**：MiniStack 若在 XPU 上有 arch/节点问题，
   用 Q3_K_M（15.6 GB）+ 原版 TE 走 ComfyUI-GGUF 流式。
4. **Turbo LoRA 全场景叠加**：4-8 步是 12 GB iGPU 唯一现实的迭代速度。
