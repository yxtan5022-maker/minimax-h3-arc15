# download-h3-models.ps1 - 下载 H3 量化文件集（含 SHA-256 校验，支持断点续传）
# 用法:
#   powershell -ExecutionPolicy Bypass -File scripts/download-h3-models.ps1 -Set ministack -ComfyUIPath C:\ComfyUI
#   powershell -ExecutionPolicy Bypass -File scripts/download-h3-models.ps1 -Set ministack -ComfyUIPath C:\ComfyUI -VerifyOnly
# 参数:
#   -Set         ministack(推荐) | w4a8 | gguf-q3 | turbo-lora | all
#   -ComfyUIPath ComfyUI 根目录（默认 C:\ComfyUI）
#   -VerifyOnly  只校验已下载文件的 SHA-256，不下载
# 说明: 文件清单与 SHA-256 见 docs/quant-catalog.md；下载用 curl.exe -C - 断点续传。

param(
    [Parameter(Mandatory=$true)][ValidateSet('ministack','w4a8','gguf-q3','turbo-lora','all')][string]$Set,
    [string]$ComfyUIPath = 'C:\ComfyUI',
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
$HF = 'https://huggingface.co'

# ---- 文件清单: repo | 远端路径 | ComfyUI 相对目标 | SHA-256(可空) ----
$Manifest = @{
    'ministack' = @(
        @{ repo='woodfireind/MiniMax-H3-GGUF-MiniStack'; src='diffusion_models/MiniMax-H3-FL2VA-pruned-Q4_K_M.gguf'; dst='models\diffusion_models\MiniMax-H3-FL2VA-pruned-Q4_K_M.gguf'; sha='51783047a6be43c9fcedc3c0a1746480dac867839ba1ad2e1c698da9d7058201' },
        @{ repo='woodfireind/MiniMax-H3-GGUF-MiniStack'; src='text_encoders/qwen3vl-4b-h3student-Q4_K_M.gguf'; dst='models\text_encoders\qwen3vl-4b-h3student-Q4_K_M.gguf'; sha='7ff66b1541723fc4c4c3f2cba75f72740fad43276ab1d6d564379e591a2e74e5' },
        @{ repo='woodfireind/MiniMax-H3-GGUF-MiniStack'; src='text_encoders/te_adapter_v1.safetensors'; dst='models\text_encoders\te_adapter_v1.safetensors'; sha='ef2060e1a277820416d895812dd580234d3c2760af8e6d203b38e3df2e0952b0' },
        @{ repo='woodfireind/MiniMax-H3-GGUF-MiniStack'; src='text_encoders/h3_tokenizer/tokenizer.json'; dst='models\text_encoders\h3_tokenizer\tokenizer.json'; sha='a5d85b6dcc535e6b93115a9ef287e6132fdbf30270da6218194ba742261173c7' },
        @{ repo='woodfireind/MiniMax-H3-GGUF-MiniStack'; src='text_encoders/h3_tokenizer/tokenizer_config.json'; dst='models\text_encoders\h3_tokenizer\tokenizer_config.json'; sha='a07e942ac874baa13758de8d1fbdb186683cc03416b5589e1b6671c6b3057c68' },
        @{ repo='woodfireind/MiniMax-H3-GGUF-MiniStack'; src='text_encoders/h3_tokenizer/vocab.json'; dst='models\text_encoders\h3_tokenizer\vocab.json'; sha='ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910' },
        @{ repo='woodfireind/MiniMax-H3-GGUF-MiniStack'; src='text_encoders/h3_tokenizer/merges.txt'; dst='models\text_encoders\h3_tokenizer\merges.txt'; sha='599bab54075088774b1733fde865d5bd747cbcc7a547c5bc12610e874e26f5e3' },
        @{ repo='woodfireind/MiniMax-H3-GGUF-MiniStack'; src='vae/minimax_h3_video_vae_fp16.safetensors'; dst='models\vae\minimax_h3_video_vae_fp16.safetensors'; sha='7c1f131492e7eddacaac9069a61b81bdd39de5cc96561e677c5eab1cdce5e522' },
        @{ repo='woodfireind/MiniMax-H3-GGUF-MiniStack'; src='custom_nodes/h3_small_te/__init__.py'; dst='custom_nodes\h3_small_te\__init__.py'; sha=$null },
        @{ repo='woodfireind/MiniMax-H3-GGUF-MiniStack'; src='custom_nodes/h3_small_te/nodes.py'; dst='custom_nodes\h3_small_te\nodes.py'; sha=$null }
    )
    'w4a8' = @(
        @{ repo='Winnougan/MiniMax-H3-INT4_Convrot_ComfyUI'; src='minimax_h3_fl2va_pruned-w4a8_convrot_pruned.safetensors'; dst='models\diffusion_models\minimax_h3_fl2va_pruned-w4a8_convrot_pruned.safetensors'; sha='8b624de0ab7554bb507c4486093d4c93e0bf2eb2a40c2382f26eb0af7cd97407' },
        @{ repo='Winnougan/MiniMax-H3-INT4_Convrot_ComfyUI'; src='qwen3vl_32b_minimax_h3-w4a8_convrot.safetensors'; dst='models\text_encoders\qwen3vl_32b_minimax_h3-w4a8_convrot.safetensors'; sha='808e3b351e71e3dd2444e2cdd6accc701e5b40254ede13d481936e6332c7a0e2' }
    )
    'gguf-q3' = @(
        @{ repo='Abiray/MiniMax-H3-GGUF'; src='unet/MiniMax-H3-FL2VA-Q3_K_M.gguf'; dst='models\diffusion_models\MiniMax-H3-FL2VA-Q3_K_M.gguf'; sha='5cf5285fbedf870ce4e74b49cd3d14b8d508a59ea5be8fa8699a4d4f728c41df' },
        @{ repo='Abiray/MiniMax-H3-GGUF'; src='text_encoders/qwen3vl_32b_minimax_h3-Q4_K_M.gguf'; dst='models\text_encoders\qwen3vl_32b_minimax_h3-Q4_K_M.gguf'; sha='ccfaa8d786cafce211cb4cd3ab69b64a5240f124eb237d62c0178e58d3ba5121' }
    )
    'turbo-lora' = @(
        @{ repo='larryvrh/MiniMax-H3-Turbo-Lora'; src='minimax_h3_turbo_v4_step600_ema.safetensors'; dst='models\loras\minimax_h3_turbo_v4_step600_ema.safetensors'; sha='5f3a626cd72c93a8b9318d6760c510bc5092d2ab13aaba1f932c5bab07a416d3' }
    )
}

$sets = if ($Set -eq 'all') { @('ministack','w4a8','turbo-lora') } else { @($Set) }
$files = @(); foreach ($s in $sets) { $files += $Manifest[$s] }

function Test-Sha256([string]$Path, [string]$Expected) {
    if (-not (Test-Path $Path)) { return 'missing' }
    if (-not $Expected) { return 'skip' }
    $h = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLower()
    if ($h -eq $Expected.ToLower()) { return 'ok' } else { return 'MISMATCH' }
}

$Curl = (Get-Command curl.exe -ErrorAction SilentlyContinue).Source
if (-not $Curl) { $Curl = (Get-Command curl -ErrorAction SilentlyContinue).Source }
if (-not $Curl -and -not $VerifyOnly) { throw '未找到 curl：Win10 1803+ 自带 curl.exe，或请安装 curl' }

$fail = @(); $okCount = 0
foreach ($f in $files) {
    $dst = Join-Path $ComfyUIPath $f.dst
    $name = Split-Path $f.dst -Leaf
    if ($VerifyOnly) {
        $r = Test-Sha256 $dst $f.sha
        Write-Host ("{0,-9} {1}" -f $r, $f.dst)
        if ($r -eq 'MISMATCH' -or $r -eq 'missing') { $fail += $f.dst } else { $okCount++ }
        continue
    }
    $url = "$HF/$($f.repo)/resolve/main/$($f.src)"
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    # 已存在且校验通过则跳过
    if ((Test-Path $dst) -and ((Test-Sha256 $dst $f.sha) -eq 'ok')) {
        Write-Host "SKIP(ok) $name"; $okCount++; continue
    }
    Write-Host "GET $name  <- $($f.repo)/$($f.src)"
    & $Curl -L -C - --retry 5 --retry-delay 10 -o $dst $url
    if ($LASTEXITCODE -ne 0) { Write-Host "FAIL(download) $name"; $fail += $f.dst; continue }
    $r = Test-Sha256 $dst $f.sha
    if ($r -eq 'ok' -or $r -eq 'skip') { Write-Host "OK($r) $name"; $okCount++ }
    else { Write-Host "FAIL(sha256) $name"; $fail += $f.dst }
}

Write-Host ''
Write-Host ("完成: {0} 成功 / {1} 失败" -f $okCount, $fail.Count)
if ($fail.Count) { $fail | ForEach-Object { Write-Host "  失败: $_" }; exit 1 }
