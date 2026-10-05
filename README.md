# 找回 Logitech G HUB 耳机的 Windows“响度均衡”

[English](#english)

装了 G HUB 之后，Logitech PRO X Wireless 的声音属性里没有“增强”页，也就用不了 Windows 自带的“响度均衡”(Loudness Equalization)。这个 PowerShell 脚本会把 Windows 自带的音效组件加回耳机的音效链，同时保留 G HUB 的 DTS Headphone:X 环绕声。

## 原因

- G HUB 安装的罗技驱动用自家的 DTS 组件替换了 Windows 自带的音效组件，而响度均衡属于 Windows 那一套。
- 有些电脑上（例如部分带 intelliGo AI 降噪的戴尔电脑），intelliGo 服务还会改写所有音频设备的音效链，把罗技的 DTS 组件也挤掉，导致 G HUB 里的 DTS 环绕声失效。脚本会把它加回来。

## 脚本做了什么

只修改耳机播放设备的音效配置，也就是注册表里的 `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\{设备 ID}\FxProperties`：

| 位置 | 修改后 |
| --- | --- |
| SFX（流效果） | 罗技 DTS 组件 → Windows 音效组件 → 原有的其他组件 |
| MFX（模式效果） | Windows 音效组件（响度均衡在这里）→ 原有的其他组件 |
| 属性页 | Windows 的“增强”页 |
| 响度均衡 | 打开 |

第一次运行时会自动备份原始设置，加 `-Restore` 运行即可原样还原。

## 使用方法

1. 下载 [`enable-loudness-eq.ps1`](enable-loudness-eq.ps1)，放进一个单独的文件夹（备份文件也会存在这里）。
2. 插上接收器，打开耳机。
3. 在这个文件夹里打开 PowerShell，运行：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File enable-loudness-eq.ps1
   ```

4. 弹出管理员权限确认时点“是”。Windows 音频服务会重启，声音会断一两秒。
5. 在弹出的“声音”窗口里双击耳机，打开“增强”页，确认“响度均衡”已勾选。DTS 环绕声照常在 G HUB 里开关。

还原：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File enable-loudness-eq.ps1 -Restore
```

其他使用 G HUB 驱动的罗技耳机，可以用 `-DeviceName` 指定设备名称里的关键字（未测试）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File enable-loudness-eq.ps1 -DeviceName "G733"
```

## 注意

- 需要 Windows 10 1803 或更高版本。已在 Windows 11、G HUB 2024.7 驱动、PRO X Wireless 上测试。
- G HUB 更新耳机驱动后，或者接收器插到以前没用过的 USB 口时，设置可能失效，再运行一次即可。
- 脚本修改的是系统音频配置，使用风险自负。出现问题可以用 `-Restore` 还原，或者在 Windows 设置 → 系统 → 声音 → 耳机 →“音频增强”里选择“关闭”，临时停用所有音效。

## English

Logitech G HUB's driver replaces Windows' built-in audio enhancements on the PRO X Wireless headset, so Loudness Equalization disappears. On some PCs the intelliGo noise-suppression service also rewrites every endpoint's effect chain and drops G HUB's DTS Headphone:X effect.

This script rebuilds the headset's effect chain as *DTS → Windows enhancements → existing effects*, restores the Enhancements tab and turns Loudness Equalization on. It backs up the original settings on the first run, and `-Restore` puts them back. Run it from the folder containing the script (it asks for elevation to restart the audio service):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File enable-loudness-eq.ps1
```

## License

[MIT](LICENSE)
