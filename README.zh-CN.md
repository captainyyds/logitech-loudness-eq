# 找回 Logitech G HUB 耳机的“响度均衡”

[English](README.md) | 简体中文

这是一个 PowerShell 脚本，用于在使用 G HUB 驱动的罗技耳机（例如 **PRO X Wireless**）上找回 Windows 自带的**响度均衡**(Loudness Equalization)，同时保留 G HUB 的 **DTS Headphone:X** 环绕声。

- 把 Windows 自带的音效组件加回耳机的音效链。
- 加回“声音”控制面板里的**增强**页，并打开响度均衡。
- 保留 G HUB 的 DTS 组件和设备上已有的其他音效；如果 DTS 被其他音频软件挤掉了，会把它加回来。
- 第一次运行时自动备份原始设置，`-Restore` 可原样还原。

## 为什么没有响度均衡

Windows 自带的音效（低音增强、虚拟环绕、房间校正、响度均衡）都是“音频处理对象”(APO)，由设备驱动登记在设备的音效配置里。G HUB 安装的耳机驱动登记的是罗技自家的 DTS Headphone:X 组件，而不是 Windows 的组件，所以**增强**页消失，响度均衡也跟着没了。

有些电脑上还有第二个问题：会给所有音频设备加自家音效的软件，可能把 G HUB 的 DTS 组件挤出音效链。开发这个脚本时用的电脑是一台带 intelliGo AI 降噪的戴尔电脑，intelliGo 服务把耳机的音效链改成了只剩它自己的组件，G HUB 里的 DTS 环绕声因此也悄悄失效了。

## 脚本修改了什么

脚本只修改耳机播放设备的音效配置，位于注册表：

```
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\{设备 ID}\FxProperties
```

| 音效位置 | 只装了 G HUB | G HUB + intelliGo（测试电脑） | 运行脚本后 |
| --- | --- | --- | --- |
| 流效果 (SFX) | 罗技 DTS | intelliGo（DTS 被挤掉） | 罗技 DTS → Windows 音效 → 原有的其他音效 |
| 模式效果 (MFX) | 无 | intelliGo | Windows 音效（响度均衡）→ 原有的其他音效 |
| 属性页 | 罗技 | 无 | Windows 的“增强”页 |
| 响度均衡 | 不可用 | 不可用 | 打开 |

接收器每插到一个以前没用过的 USB 口，Windows 都会新建一个播放设备。脚本会修改所有名称匹配的播放设备，所以现在插在哪个口都没关系。

具体的注册表值见[工作原理](#工作原理)。

## 运行要求

- Windows 10 1803 或更高版本，或 Windows 11。脚本用到的“组合音效列表”是 Windows 10 1803 加入的。
- Windows PowerShell 5.1（Windows 自带）。
- 已安装 Logitech G HUB 及其耳机驱动。
- 管理员权限，用于重启“Windows 音频”服务，脚本会通过 UAC 提示申请。

## 测试环境

- Windows 11，版本号 26300
- Logitech PRO X Wireless，G HUB 耳机驱动 2024.7.60.8851
- 装有 intelliGo 音效组件（戴尔）

运行脚本后，响度均衡、“增强”页和 DTS Headphone:X 均已确认可以正常使用。

## 使用方法

1. 下载整个仓库（**Code → Download ZIP**）并解压，或者只下载 `enable-loudness-eq.ps1`。把脚本放在单独的文件夹里，因为备份文件会保存在脚本旁边。
2. 插上接收器，打开耳机。
3. 在这个文件夹里打开 PowerShell：可以在资源管理器的地址栏输入 `powershell` 后按回车。然后运行：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\enable-loudness-eq.ps1
   ```

   `-ExecutionPolicy Bypass` 只对这一次运行有效，不会改动系统的执行策略。
4. UAC 提示弹出时点**是**。脚本会重启“Windows 音频”服务，声音会断一两秒。
5. 弹出“声音”控制面板后，双击耳机，打开**增强**页，确认**响度均衡**已勾选。
6. DTS Headphone:X 2.0 照常在 G HUB 里开关。

第一次听之前先把音量调小一点，因为响度均衡会把小声的部分放大。

### 脚本会输出什么

1. 每个播放设备新的 SFX 和 MFX 音效链，例如 `EagleAPOLFX → WM audio LFX APO → intelliGo SFX2`。`EagleAPOLFX` 是 G HUB 的 DTS 组件，`WM audio` 开头的是 Windows 自带的音效组件。
2. 音频服务重启几秒后，检查所有设置是否还在，因为其他音频软件可能会把它们改回去。
3. 播放三秒静音时，音频引擎实际加载了哪些音效 DLL。只有耳机是默认播放设备时，这项检查才有意义。

### 参数

| 参数 | 说明 |
| --- | --- |
| `-DeviceName <文字>` | 耳机播放设备名称中必须包含的文字，默认 `PRO X Wireless`。 |
| `-Restore` | 按备份还原原始设置。 |

### 撤销

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\enable-loudness-eq.ps1 -Restore
```

这会把脚本改过的每一项写回原值，删除原本不存在的项，然后重启音频服务。脚本没有安装任何东西，所以不需要再卸载别的。

### 脚本生成的文件

| 文件 | 用途 |
| --- | --- |
| `loudness-eq-backup.json` | 每个设备上被脚本修改的各项原始值。第一次运行时写入，之后不会被覆盖，`-Restore` 用的就是它。 |
| `backup-{设备 ID}.reg` | 第一次修改前，每个设备音效配置的完整导出，作为额外保险。 |
| `loudness-eq.log` | 每次运行的完整记录。 |

如果以后可能要撤销，请保留这些文件。

## 其他罗技耳机

G HUB 驱动包给另外几款耳机用的是同一个 DTS 组件，包括 G431、G432、G635、G733、G735 和 G935。脚本会自动找到每款耳机自己的组件，所以理论上也适用，但还没有测试过。使用时传入“声音”设置里显示的设备名称的一部分：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\enable-loudness-eq.ps1 -DeviceName "G733"
```

## 常见问题

| 问题 | 解决办法 |
| --- | --- |
| 提示“在此系统上禁止运行脚本” | 使用上面给出的完整命令，`-ExecutionPolicy Bypass` 会允许这一次运行。 |
| 脚本找不到播放设备 | 插上接收器、打开耳机，在**设置 → 系统 → 声音**里查看设备名称，用 `-DeviceName` 传入其中一部分。 |
| 拒绝了 UAC 提示，或者没有管理员权限 | 脚本会在不重启音频服务的情况下继续。如果设置写入成功，拔插一次接收器或重启电脑即可生效。 |
| 没有“增强”页，或者响度均衡没有勾上 | 在**设置 → 系统 → 声音**里打开耳机，确认**音频增强**没有设成**关闭**。然后再运行一次脚本，看它的检查结果。 |
| 没有声音或声音失真 | 用 `-Restore` 运行脚本，或者把**音频增强**设成**关闭**，暂时停用所有音效。 |
| 过一段时间后失效了 | 更新或重装 G HUB 耳机驱动会重置音效配置，有些音频软件也会改写它；接收器插到从没用过的 USB 口会产生新的播放设备。这些情况下都再运行一次脚本即可。 |
| DTS 好像没有效果 | 确认 G HUB 里已经打开 DTS Headphone:X 2.0，并且脚本输出里 `EagleAPOLFX` 显示为已加载。不要同时开启 Windows 的空间音效或“增强”页里的虚拟环绕。 |
| 响度均衡调整得太快或太慢 | 在“增强”页选中**响度均衡**，点**设置**，调整**释放时间**。 |

## 工作原理

Windows 通过音频处理对象 (APO) 来处理音效。每个播放设备的 `FxProperties` 注册表项记录了哪个位置运行哪些 APO：

| 值名称 | 含义 |
| --- | --- |
| `{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},1` | 旧式混音前效果 (LFX) |
| `{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},3` | “声音”控制面板里显示的属性页 |
| `{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},5` | 流效果 (SFX)，只能有一个 APO |
| `{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},6` | 模式效果 (MFX)，只能有一个 APO |
| `{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},13` | 组合流效果：SFX APO 列表（Windows 10 1803 及以上） |
| `{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},14` | 组合模式效果：MFX APO 列表 |
| `{D3993A3F-99C2-4402-B5EC-A92A0367664B},5` 和 `,6` | SFX 和 MFX 支持的处理模式 |
| `{fc52a749-4be9-4510-896e-966ba6525980},3` | 响度均衡开关 |

背景知识：

- 从 Windows 8.1 开始，只要设备有任何 SFX、MFX 或 EFX 项，Windows 就会忽略旧式的 LFX 和 GFX 项。
- G HUB 驱动把它的 DTS 组件 `EagleAPOLFX`（`{A8CF6A24-68AE-499B-896A-0C631102AEB8}`，`logi_audio_hx2e_render_apo.dll`）同时登记为 LFX 和 SFX，属性页则指向罗技自己的页面。
- 在测试电脑上，耳机的 SFX 项和属性页都已经没了，组合列表里只有 intelliGo 的组件，只剩被忽略的 LFX 项里还写着 DTS。
- Windows 自带的音效组件是 `WM audio LFX APO`（`{C9453E73-8C5C-4463-9984-AF8BAB2F5447}`，用作 SFX）和 `WM audio GFX APO`（`{13AB3EBD-137E-4903-9D89-60BE8277FD17}`，用作 MFX），都在 `WMALFXGFXDSP.dll` 里，对应的“增强”页是 `{5860E1C5-F95C-4a7a-8EC8-8AEF24F379A1}`。Windows 自带的 USB 音频驱动 (`wdma_usb.inf`) 给 USB 耳机配的也正是这几个组件。

对每个名称匹配的播放设备，脚本会：

1. 从 SFX 项找出耳机自己的组件；如果 SFX 项已经没了，就从 LFX 项找。
2. 组建 SFX 组合列表：耳机自己的组件在最前，然后是 Windows 的 SFX 组件，再接上列表里原有的所有组件。
3. 组建 MFX 组合列表：Windows 的 MFX 组件在最前，再接上原有的组件。
4. 把单个的 SFX、MFX 项并入列表后删除，确保每个组件只加载一次。
5. 把属性页设为 Windows 的“增强”页，补上缺失的默认处理模式，并打开响度均衡。如果设备原来有别的属性页（例如罗技的），会被替换，`-Restore` 可以换回来。
6. 重启“Windows 音频”服务，让新的音效链生效。

重复运行是安全的：顺序保持不变，也不会重复添加组件。

## 免责声明

这个脚本会修改系统音频设置。它会备份所有改动，`-Restore` 也能撤销，但使用风险需自行承担。本项目与 Logitech、Microsoft 和 intelliGo 均无关联。

## 参考资料

- Microsoft：[Audio Processing Object Architecture](https://learn.microsoft.com/windows-hardware/drivers/audio/audio-processing-object-architecture)
- Microsoft：[PKEY_CompositeFX_StreamEffectClsid](https://learn.microsoft.com/windows-hardware/drivers/audio/pkey-compositefx-streameffectclsid)
- [Equalizer APO](https://sourceforge.net/projects/equalizerapo/) 源代码：Windows 如何在旧式和新式音效项之间选择
- [响度均衡相关注册表值的说明](https://gist.github.com/ThaTiemsz/28671465ec3ee1f690a260fd70699514)

## 许可证

[MIT](LICENSE)
