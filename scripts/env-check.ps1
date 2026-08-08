# env-check.ps1 - 采集本机硬件/软件环境快照（M0 基线用）
# 用法: powershell -ExecutionPolicy Bypass -File scripts/env-check.ps1

$ErrorActionPreference = 'SilentlyContinue'

$out = [ordered]@{}
$out['timestamp'] = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

$cs = Get-CimInstance Win32_ComputerSystem
$out['manufacturer'] = $cs.Manufacturer
$out['model'] = $cs.Model
$out['ram_bytes'] = $cs.TotalPhysicalMemory
$out['ram_gib'] = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$out['cpu'] = $cpu.Name
$out['cpu_cores'] = $cpu.NumberOfCores
$out['cpu_threads'] = $cpu.NumberOfLogicalProcessors

$gpu = Get-CimInstance Win32_VideoController
$out['gpu_list'] = @($gpu | ForEach-Object { $_.Name })
$out['gpu_resolution'] = "$(($gpu | Select-Object -First 1).CurrentHorizontalResolution)x$(($gpu | Select-Object -First 1).CurrentVerticalResolution)"

$drv = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*'
$out['gpu_driver'] = $drv.DriverVersion | Select-Object -First 1
$out['gpu_device_ids'] = @($drv.MatchingDeviceId | Select-Object -First 3)

$os = Get-CimInstance Win32_OperatingSystem
$out['os'] = $os.Caption
$out['powershell'] = $PSVersionTable.PSVersion.ToString()

try { $out['python'] = (& python --version 2>&1 | Out-String).Trim() } catch { $out['python'] = 'n/a' }
try { $out['git'] = (& git --version 2>&1 | Out-String).Trim() } catch { $out['git'] = 'n/a' }
try { $out['gh'] = (& gh --version 2>&1 | Out-String).Trim().Split("`n")[0] } catch { $out['gh'] = 'n/a' }

$d = Get-PSDrive -Name C
$out['disk_C_used_gib'] = [math]::Round($d.Used / 1GB, 1)
$out['disk_C_free_gib'] = [math]::Round($d.Free / 1GB, 1)

$out['nvidia_smi'] = if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) { 'present' } else { 'absent' }

$out | ConvertTo-Json
