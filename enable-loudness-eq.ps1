<#
.SYNOPSIS
  给 Logitech G HUB 耳机加回 Windows 自带的“响度均衡”，同时保留 G HUB 的 DTS 环绕声。

.DESCRIPTION
  G HUB 安装的罗技驱动用自家的 DTS Headphone:X 组件替换了 Windows 自带的音效组件，
  而“响度均衡”(Loudness Equalization) 属于后者，所以耳机属性里没有“增强”页。
  有些电脑上的 intelliGo AI 降噪服务（例如部分戴尔电脑）还会改写所有音频设备的音效链，
  把罗技的 DTS 组件也挤掉，G HUB 里的 DTS 环绕声因此失效。

  本脚本把耳机的音效链整理为：
    SFX：罗技 DTS 组件 → Windows 自带音效组件 → 原有的其他组件（如 intelliGo）
    MFX：Windows 自带音效组件（响度均衡）→ 原有的其他组件
  然后加回“增强”页并打开响度均衡。第一次运行时自动备份，加 -Restore 可原样还原。

  需要 Windows 10 1803 或更高版本。

.PARAMETER DeviceName
  耳机播放设备名称中的关键字，默认 "PRO X Wireless"。

.PARAMETER Restore
  按备份还原。

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File enable-loudness-eq.ps1

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File enable-loudness-eq.ps1 -Restore
#>
param(
    [string]$DeviceName = 'PRO X Wireless',
    [switch]$Restore,
    [switch]$Elevated
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if ([Environment]::OSVersion.Version.Build -lt 17134) {
    Write-Host '需要 Windows 10 1803 或更高版本。' -ForegroundColor Red
    exit 1
}

# 重启“Windows 音频”服务需要管理员权限，先尝试以管理员身份重新运行
if (-not $isAdmin -and -not $Elevated) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Elevated', '-DeviceName', "`"$DeviceName`"")
    if ($Restore) { $argList += '-Restore' }
    try {
        $p = Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList $argList -Wait -PassThru
        exit $p.ExitCode
    } catch {
        Write-Host '没有获得管理员权限，改用普通权限继续（最后需要手动拔插一次接收器）。' -ForegroundColor Yellow
    }
}

try { Start-Transcript -Path (Join-Path $here 'loudness-eq.log') -Append | Out-Null } catch { }

# Windows 自带音效组件（WMALFXGFXDSP.dll）和它的“增强”属性页
$MS_SFX = '{C9453E73-8C5C-4463-9984-AF8BAB2F5447}'
$MS_MFX = '{13AB3EBD-137E-4903-9D89-60BE8277FD17}'
$MS_UI  = '{5860E1C5-F95C-4a7a-8EC8-8AEF24F379A1}'
# 不当作“厂商组件”的 Windows 组件（含旧版 LFX/GFX）
$MS_CLSIDS = $MS_SFX, $MS_MFX, '{62dc1a93-ae24-464c-a43e-452f824c4250}', '{637c490d-eee3-4c0a-973f-371958802da2}'

# FxProperties 里的属性键
$K_LFX       = '{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},1'   # 旧式 LFX（罗技驱动在这里也登记了 DTS 组件）
$K_UI        = '{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},3'   # 属性页（“增强”页）
$K_SFX       = '{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},5'   # 单个 SFX
$K_MFX       = '{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},6'   # 单个 MFX
$K_COMP_SFX  = '{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},13'  # SFX 组合列表（存在时取代单个 SFX）
$K_COMP_MFX  = '{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},14'  # MFX 组合列表
$K_SFX_MODES = '{D3993A3F-99C2-4402-B5EC-A92A0367664B},5'
$K_MFX_MODES = '{D3993A3F-99C2-4402-B5EC-A92A0367664B},6'
$K_LOUDNESS  = '{fc52a749-4be9-4510-896e-966ba6525980},3'   # 响度均衡开关
$LOUDNESS_ON = [byte[]](0x0b, 0, 0, 0, 1, 0, 0, 0, 0xff, 0xff, 0, 0)  # VT_BOOL = TRUE
$MODE_DEFAULT = '{C18E2F7E-933D-4965-B7D1-1EEF228D2AF3}'
$TOUCHED = $K_COMP_SFX, $K_COMP_MFX, $K_SFX, $K_MFX, $K_UI, $K_LOUDNESS, $K_SFX_MODES, $K_MFX_MODES

$renderPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render'
$hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64')
$backupPath = Join-Path $here 'loudness-eq-backup.json'

function Find-Endpoints([string]$name) {
    $render = $hklm.OpenSubKey($renderPath)
    foreach ($guid in $render.GetSubKeyNames()) {
        $props = $render.OpenSubKey("$guid\Properties")
        if (-not $props) { continue }
        $device = $props.GetValue('{b3f8fa53-0004-438e-9003-51a46e139bfc},6')
        $props.Close()
        if ($device -like "*$name*") { $guid }
    }
    $render.Close()
}

function Read-Value($key, [string]$name) {
    if ($key.GetValueNames() -notcontains $name) { return [pscustomobject]@{ Name = $name; Exists = $false } }
    $kind = $key.GetValueKind($name)
    $data = $key.GetValue($name, $null, 'DoNotExpandEnvironmentNames')
    if ($kind -eq 'Binary') { $data = [Convert]::ToBase64String($data) }
    [pscustomobject]@{ Name = $name; Exists = $true; Kind = "$kind"; Data = $data }
}

function Write-Value($key, $v) {
    if (-not $v.Exists) {
        if ($key.GetValueNames() -contains $v.Name) { $key.DeleteValue($v.Name) }
        return
    }
    $kind = [Microsoft.Win32.RegistryValueKind]$v.Kind
    switch ($kind) {
        'Binary'      { $data = [Convert]::FromBase64String($v.Data) }
        'MultiString' { $data = [string[]]@($v.Data) }
        'DWord'       { $data = [int]$v.Data }
        default       { $data = [string]$v.Data }
    }
    $key.SetValue($v.Name, $data, $kind)
}

# 驱动自带的流效果（罗技 DTS 组件）：先看单个 SFX，没有就看旧式 LFX
function Get-VendorSfx($key) {
    foreach ($name in $K_SFX, $K_LFX) {
        $clsid = $key.GetValue($name)
        if ($clsid -and $MS_CLSIDS -notcontains $clsid) { return [string]$clsid }
    }
    $null
}

# 组合列表 = 厂商组件（若有，放最前）+ 原有组件，缺 Windows 组件就补在厂商组件之后。
# 原来的单个组件已并入列表，删掉以免重复加载。
function Set-Chain($key, [string]$compName, [string]$singleName, [string]$ms, [string]$vendor) {
    $current = $key.GetValue($compName)
    if ($null -eq $current) { $current = $key.GetValue($singleName) }
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($c in @($vendor) + @($current)) { if ($c -and -not ($list -contains $c)) { $list.Add($c) } }
    if (-not ($list -contains $ms)) { $list.Insert([int][bool]$vendor, $ms) }
    $key.SetValue($compName, [string[]]$list.ToArray(), 'MultiString')
    if ($key.GetValueNames() -contains $singleName) { $key.DeleteValue($singleName) }
    $list.ToArray()
}

# 查音效组件的名称和 DLL：先查全局注册，再查 Windows 11 的组件式注册（FxProperties 里记着组件设备）
function Get-ApoInfo($fxKey, [string]$clsid) {
    $roots = @(, @('Registry::HKEY_CLASSES_ROOT\CLSID', 'Registry::HKEY_CLASSES_ROOT\AudioEngine\AudioProcessingObjects'))
    $inst = $fxKey.GetValue("$clsid,100")
    if ($inst) {
        $drv = (Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Enum\$inst" -ErrorAction SilentlyContinue).Driver
        if ($drv) {
            $class = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$drv"
            $roots += , @("$class\Classes\CLSID", "$class\AudioEngine\AudioProcessingObjects")
        }
    }
    foreach ($r in $roots) {
        $dll = (Get-ItemProperty -LiteralPath "$($r[0])\$clsid\InprocServer32" -ErrorAction SilentlyContinue).'(default)'
        if ($dll) {
            $name = (Get-ItemProperty -LiteralPath "$($r[1])\$clsid" -ErrorAction SilentlyContinue).FriendlyName
            return [pscustomobject]@{ Name = $(if ($name) { $name } else { $clsid }); Dll = [IO.Path]::GetFileName($dll) }
        }
    }
    [pscustomobject]@{ Name = $clsid; Dll = $null }
}

# 修改一个设备的音效配置；先在 $entry 里补记备份还没有的项（它们还没被改过，当前值就是原始值）
function Update-FxKey($key, $entry) {
    $known = @($entry.Values | ForEach-Object { $_.Name })
    $entry.Values = @($entry.Values) + @($TOUCHED | Where-Object { $known -notcontains $_ } | ForEach-Object { Read-Value $key $_ })

    $vendor = Get-VendorSfx $key
    $sfx = Set-Chain $key $K_COMP_SFX $K_SFX $MS_SFX $vendor
    $mfx = Set-Chain $key $K_COMP_MFX $K_MFX $MS_MFX $null
    foreach ($m in $K_SFX_MODES, $K_MFX_MODES) {
        if ($null -eq $key.GetValue($m)) { $key.SetValue($m, [string[]]@($MODE_DEFAULT), 'MultiString') }
    }
    $ui = $key.GetValue($K_UI)
    if ($ui -ne $MS_UI) {
        if ($ui) { Write-Host "  原来的音效页 $ui 已换成 Windows 的“增强”页（-Restore 可还原）" }
        $key.SetValue($K_UI, $MS_UI, 'String')
    }
    $key.SetValue($K_LOUDNESS, $LOUDNESS_ON, 'Binary')
    [pscustomobject]@{ Sfx = $sfx; Mfx = $mfx }
}

function Test-FxKey($key) {
    $vendor = Get-VendorSfx $key
    $sfx = @($key.GetValue($K_COMP_SFX))
    $mfx = @($key.GetValue($K_COMP_MFX))
    $loud = $key.GetValue($K_LOUDNESS)
    [pscustomobject]@{
        DTS      = (-not $vendor) -or ($sfx -contains $vendor)
        SFX      = $sfx -contains $MS_SFX
        MFX      = $mfx -contains $MS_MFX
        UI       = $key.GetValue($K_UI) -eq $MS_UI
        Loudness = ($null -ne $loud) -and (($loud -join ',') -eq ($LOUDNESS_ON -join ','))
        Chain    = @($sfx + $mfx | Where-Object { $_ })
    }
}

function New-SilentWav([int]$seconds) {
    $rate = 48000; $channels = 2; $bytesPerSample = 2
    $dataLen = $rate * $channels * $bytesPerSample * $seconds
    $ms = New-Object IO.MemoryStream
    $w = New-Object IO.BinaryWriter($ms)
    $w.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $w.Write([int](36 + $dataLen))
    $w.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt ')); $w.Write([int]16)
    $w.Write([int16]1); $w.Write([int16]$channels); $w.Write([int]$rate)
    $w.Write([int]($rate * $channels * $bytesPerSample)); $w.Write([int16]($channels * $bytesPerSample)); $w.Write([int16]16)
    $w.Write([Text.Encoding]::ASCII.GetBytes('data')); $w.Write([int]$dataLen); $w.Write((New-Object byte[] $dataLen))
    $ms.Position = 0
    $ms
}

$backup = @()
if (Test-Path $backupPath) {
    # Windows PowerShell 的 ConvertFrom-Json 会把整个数组当成一个对象输出，这里逐项展开
    foreach ($e in (Get-Content $backupPath -Raw -Encoding UTF8 | ConvertFrom-Json)) { $backup += $e }
}
$targets = @()

if ($Restore) {
    if ($backup.Count -eq 0) {
        Write-Host '没有找到备份文件 loudness-eq-backup.json，无法还原。' -ForegroundColor Red
        exit 1
    }
    foreach ($entry in $backup) {
        $key = $hklm.OpenSubKey("$renderPath\$($entry.Guid)\FxProperties", $true)
        if (-not $key) { continue }
        foreach ($v in $entry.Values) { Write-Value $key $v }
        $key.Close()
        Write-Host "已还原 $($entry.Guid)"
    }
} else {
    $targets = @(Find-Endpoints $DeviceName)
    if ($targets.Count -eq 0) {
        Write-Host "没找到名称包含“$DeviceName”的播放设备：请插上接收器、打开耳机后再运行。" -ForegroundColor Red
        exit 1
    }
    foreach ($guid in $targets) {
        $fxPath = "$renderPath\$guid\FxProperties"
        try { $key = $hklm.OpenSubKey($fxPath, $true) } catch {
            Write-Host "无法写入 $guid：$($_.Exception.Message)" -ForegroundColor Red
            continue
        }
        if (-not $key) { Write-Host "跳过 $guid（没有音效配置）"; continue }

        # 第一次处理这个设备时记录原始状态，重复运行不会覆盖
        $entry = @($backup | Where-Object { $_.Guid -eq $guid })[0]
        if (-not $entry) {
            $entry = [pscustomobject]@{ Guid = $guid; Values = @() }
            $backup += $entry
            & reg.exe export "HKLM\$fxPath" (Join-Path $here "backup-$guid.reg") /y | Out-Null
        }
        $result = Update-FxKey $key $entry
        Write-Host "已修改 $guid"
        Write-Host ('  SFX：' + (($result.Sfx | ForEach-Object { (Get-ApoInfo $key $_).Name }) -join ' → '))
        Write-Host ('  MFX：' + (($result.Mfx | ForEach-Object { (Get-ApoInfo $key $_).Name }) -join ' → '))
        $key.Close()
    }
    Set-Content -Path $backupPath -Value (ConvertTo-Json -InputObject @($backup) -Depth 6) -Encoding UTF8
}

if ($isAdmin) {
    Write-Host '正在重启“Windows 音频”服务……'
    try {
        Restart-Service -Name Audiosrv -Force
        Start-Sleep -Seconds 5
    } catch {
        Write-Host "重启音频服务失败：$($_.Exception.Message)。请重启电脑让设置生效。" -ForegroundColor Yellow
    }
} else {
    Write-Host '请拔下接收器，等几秒再插回（或重启电脑），设置才会生效。' -ForegroundColor Yellow
}

if (-not $Restore) {
    Write-Host ''
    Write-Host '检查结果（True = 已写入）：'
    $allOk = $true
    $expected = @{}
    foreach ($guid in $targets) {
        $key = $hklm.OpenSubKey("$renderPath\$guid\FxProperties")
        if (-not $key) { continue }
        $r = Test-FxKey $key
        foreach ($c in $r.Chain) {
            $info = Get-ApoInfo $key $c
            if ($info.Dll) { $expected[$info.Dll] = @($expected[$info.Dll]) + $info.Name | Where-Object { $_ } | Select-Object -Unique }
        }
        $key.Close()
        if (-not ($r.DTS -and $r.SFX -and $r.MFX -and $r.Loudness)) { $allOk = $false }
        Write-Host ("  {0}  DTS={1} Windows音效={2}/{3} 增强页={4} 响度均衡={5}" -f $guid, $r.DTS, $r.SFX, $r.MFX, $r.UI, $r.Loudness)
    }
    if (-not $allOk) {
        Write-Host '  有设置被改回去了，可能是其他音频软件（如 intelliGo）改的，可以再运行一次本脚本。' -ForegroundColor Yellow
    }

    # 播放一段静音，看音频引擎实际加载了哪些音效组件（耳机需要是默认播放设备）
    if ($isAdmin -and $expected.Count -gt 0) {
        try {
            Add-Type -Namespace LoudEq -Name Native -MemberDefinition '[DllImport("ntdll.dll")] public static extern int RtlAdjustPrivilege(int privilege, bool enable, bool currentThread, out bool wasEnabled);'
            $was = $false
            [void][LoudEq.Native]::RtlAdjustPrivilege(20, $true, $false, [ref]$was)   # SeDebugPrivilege，用来读取 audiodg 的模块列表
            $player = New-Object System.Media.SoundPlayer (New-SilentWav 3)
            $player.Play()
            Start-Sleep -Milliseconds 1500
            $loaded = @((Get-Process audiodg).Modules | ForEach-Object { $_.ModuleName })
            $player.Stop()
            Write-Host '音频引擎加载情况：'
            foreach ($dll in $expected.Keys) {
                $ok = $loaded -contains $dll
                Write-Host ("  {0} ({1})：{2}" -f ($expected[$dll] -join ' / '), $dll, $(if ($ok) { '已加载' } else { '未加载' })) -ForegroundColor $(if ($ok) { 'Green' } else { 'Yellow' })
            }
        } catch {
            Write-Host "  （跳过加载检测：$($_.Exception.Message)）"
        }
    }

    Start-Process control.exe -ArgumentList 'mmsys.cpl,,0'
    Write-Host ''
    Write-Host '完成。'
    Write-Host '1. 在弹出的“声音”窗口里双击耳机 → “增强”(Enhancements) 页，确认“响度均衡”(Loudness Equalization) 已勾选。'
    Write-Host '2. 在 G HUB 里打开耳机的 DTS Headphone:X 2.0 环绕声，找一段 7.1 环绕声测试视频听听方位感。'
    Write-Host '第一次开启响度均衡时建议先把音量调小一点。'
} else {
    Write-Host '已还原为原始设置。'
}

try { Stop-Transcript | Out-Null } catch { }
if ($Elevated) { Read-Host '按回车键关闭此窗口' }
