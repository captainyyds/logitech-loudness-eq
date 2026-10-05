# Loudness Equalization for Logitech G HUB headsets

English | [简体中文](README.zh-CN.md)

A PowerShell script that brings back Windows' built-in **Loudness Equalization** on Logitech headsets that use the G HUB driver, such as the **PRO X Wireless**, while keeping G HUB's **DTS Headphone:X** surround sound working.

- Adds the Windows audio enhancements back to the headset's effect chain.
- Restores the **Enhancements** tab in the Sound control panel and turns Loudness Equalization on.
- Keeps G HUB's DTS effect and any other effects already on the device, and puts DTS back if other audio software removed it.
- Backs up the original settings on the first run. `-Restore` puts them back exactly.

## Why Loudness Equalization is missing

Windows' audio enhancements (Bass Boost, Virtual Surround, Room Correction and Loudness Equalization) are audio processing objects (APOs) that a device's driver lists in the device's effect configuration. When G HUB installs its headset driver, the driver lists Logitech's own DTS Headphone:X APO instead of the Windows ones. The **Enhancements** tab disappears, and Loudness Equalization goes with it.

Some PCs have a second problem: audio software that adds its own effects to every audio device can push G HUB's DTS APO out of the chain. On the PC this script was developed on, a Dell with intelliGo AI noise cancellation, the intelliGo service had rewritten the headset's effect chain to contain only intelliGo's effects, so DTS in G HUB had silently stopped working as well.

## What the script changes

The script only changes the effect configuration of the headset's playback devices, stored in the registry under:

```
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\{endpoint ID}\FxProperties
```

| Effect slot | G HUB only | G HUB + intelliGo (test PC) | After running the script |
| --- | --- | --- | --- |
| Stream effects (SFX) | Logitech DTS | intelliGo (DTS dropped) | Logitech DTS → Windows enhancements → other existing effects |
| Mode effects (MFX) | none | intelliGo | Windows enhancements (Loudness Equalization) → other existing effects |
| Property page | Logitech | none | Windows Enhancements tab |
| Loudness Equalization | unavailable | unavailable | on |

Windows creates a separate playback device each time the receiver is plugged into a USB port it hasn't used before. The script updates every playback device whose name matches, so it doesn't matter which port you use now.

See [How it works](#how-it-works) for the exact registry values.

## Requirements

- Windows 10 version 1803 or later, or Windows 11. The script uses composite (multi-effect) effect lists, which were added in Windows 10 1803.
- Windows PowerShell 5.1, which is built into Windows.
- Logitech G HUB with its headset driver installed.
- Administrator rights to restart the Windows Audio service. The script asks through a UAC prompt.

## Tested on

- Windows 11, build 26300
- Logitech PRO X Wireless with G HUB headset driver 2024.7.60.8851
- intelliGo effects present (Dell)

Loudness Equalization, the Enhancements tab and DTS Headphone:X were all confirmed working after running the script.

## Usage

1. Download the repository (**Code → Download ZIP**) and extract it, or download only `enable-loudness-eq.ps1`. Keep the script in its own folder, because the backups are saved next to it.
2. Plug in the receiver and turn the headset on.
3. Open PowerShell in that folder. In File Explorer you can type `powershell` in the address bar and press Enter. Then run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\enable-loudness-eq.ps1
   ```

   `-ExecutionPolicy Bypass` applies to this run only. It doesn't change your system's execution policy.
4. Click **Yes** on the UAC prompt. The script restarts the Windows Audio service, so the sound cuts out for a second or two.
5. When the Sound control panel opens, double-click the headset, open the **Enhancements** tab and check that **Loudness Equalization** is ticked.
6. Turn DTS Headphone:X 2.0 on or off in G HUB as usual.

Turn the volume down before you first listen, because Loudness Equalization makes quiet sounds louder.

> The script's console messages are currently in Chinese. This section and the next one describe everything the script does.

### What the script prints

1. For each playback device, the new SFX and MFX chains, for example `EagleAPOLFX → WM audio LFX APO → intelliGo SFX2`. `EagleAPOLFX` is G HUB's DTS effect, and the `WM audio` APOs are the Windows enhancements.
2. A check, run a few seconds after the audio service restarts, that every setting is still in place. Other audio software can revert them.
3. Which effect DLLs the audio engine loaded while the script played three seconds of silence. This check is only meaningful when the headset is the default playback device.

### Options

| Parameter | Description |
| --- | --- |
| `-DeviceName <text>` | Text that the headset's playback device name must contain. The default is `PRO X Wireless`. |
| `-Restore` | Restores the original settings from the backup. |

### Undo

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\enable-loudness-eq.ps1 -Restore
```

This writes back the original value of every setting the script changed, removes any setting that didn't exist before, and restarts the audio service. The script doesn't install anything, so there's nothing else to remove.

### Files the script creates

| File | Purpose |
| --- | --- |
| `loudness-eq-backup.json` | Original values of every setting the script changes, for each device. It's written on the first run, never overwritten, and used by `-Restore`. |
| `backup-{endpoint ID}.reg` | A full export of each device's effect configuration before the first change, as an extra safety net. |
| `loudness-eq.log` | A transcript of every run. |

Keep these files if you might want to undo the change later.

## Other Logitech headsets

The G HUB driver package uses the same DTS effect for several other headsets, including the G431, G432, G635, G733, G735 and G935. The script finds each headset's own effect automatically, so it should work for them too, but they haven't been tested. Pass part of the device name shown in Sound settings:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\enable-loudness-eq.ps1 -DeviceName "G733"
```

## Troubleshooting

| Problem | What to do |
| --- | --- |
| "Running scripts is disabled on this system" | Use the full command shown above. `-ExecutionPolicy Bypass` allows this one run. |
| The script can't find the playback device | Plug in the receiver, turn the headset on and check the device name under **Settings → System → Sound**. Pass part of the name with `-DeviceName`. |
| You declined the UAC prompt or don't have administrator rights | The script continues without restarting the audio service. If it was able to write the settings, unplug and re-plug the receiver or restart the PC to apply them. |
| The Enhancements tab is missing, or Loudness Equalization isn't ticked | In **Settings → System → Sound**, open the headset and make sure **Audio enhancements** isn't set to **Off**. Then run the script again and read its check results. |
| No sound or distorted sound | Run the script with `-Restore`, or set **Audio enhancements** to **Off** to bypass all effects. |
| It stopped working later | Updating or reinstalling the G HUB headset driver resets the effect configuration, and some audio software rewrites it. A USB port the receiver has never used creates a new playback device. In each case, run the script again. |
| DTS doesn't seem to do anything | Make sure DTS Headphone:X 2.0 is turned on in G HUB and that the script's output lists `EagleAPOLFX` as loaded. Don't combine DTS with Windows Spatial sound or with Virtual Surround on the Enhancements tab. |
| Loudness Equalization reacts too fast or too slow | On the Enhancements tab, select **Loudness Equalization**, click **Settings** and adjust **Release Time**. |

## How it works

Windows applies audio effects through audio processing objects (APOs). For each playback device, the `FxProperties` registry key lists which APOs run in which slot:

| Value name | Meaning |
| --- | --- |
| `{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},1` | Legacy pre-mix effect (LFX) |
| `{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},3` | Property page shown in the Sound control panel |
| `{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},5` | Stream effect (SFX), one APO |
| `{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},6` | Mode effect (MFX), one APO |
| `{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},13` | Composite stream effects: a list of SFX APOs (Windows 10 1803 and later) |
| `{D04E05A6-594B-4fb6-A80D-01AF5EED7D1D},14` | Composite mode effects: a list of MFX APOs |
| `{D3993A3F-99C2-4402-B5EC-A92A0367664B},5` and `,6` | Processing modes supported by the SFX and MFX |
| `{fc52a749-4be9-4510-896e-966ba6525980},3` | Loudness Equalization on or off |

Some background:

- On Windows 8.1 and later, when a device has any SFX, MFX or EFX entries, Windows ignores its legacy LFX and GFX entries.
- G HUB's driver lists its DTS APO, `EagleAPOLFX` (`{A8CF6A24-68AE-499B-896A-0C631102AEB8}`, `logi_audio_hx2e_render_apo.dll`), as both LFX and SFX, and points the property page at Logitech's own page.
- On the test PC, the headset's SFX entry and property page were gone, and the composite lists contained only intelliGo's APOs. Only the ignored LFX entry still named DTS.
- The Windows enhancements are `WM audio LFX APO` (`{C9453E73-8C5C-4463-9984-AF8BAB2F5447}`, used as SFX) and `WM audio GFX APO` (`{13AB3EBD-137E-4903-9D89-60BE8277FD17}`, used as MFX), both in `WMALFXGFXDSP.dll`. Their Enhancements page is `{5860E1C5-F95C-4a7a-8EC8-8AEF24F379A1}`. These are the same APOs that Windows' own USB audio driver (`wdma_usb.inf`) assigns to USB headsets.

For each matching playback device, the script:

1. Finds the headset's own APO from the SFX entry, or from the LFX entry if the SFX entry is gone.
2. Builds the composite SFX list: the headset's APO first, then the Windows SFX APO, then every APO that was already in the list.
3. Builds the composite MFX list: the Windows MFX APO first, then the APOs that were already there.
4. Merges the single SFX and MFX entries into the lists and deletes them, so each APO loads only once.
5. Sets the property page to the Windows Enhancements page, adds the default processing mode where it's missing and turns Loudness Equalization on. If the device had a different property page, such as Logitech's, it's replaced; `-Restore` puts it back.
6. Restarts the Windows Audio service so the new chain takes effect.

Running the script again is safe. It keeps the same order and never adds an APO twice.

## Disclaimer

This script changes system audio settings. It backs up everything it changes, and `-Restore` undoes the change, but you use it at your own risk. This project isn't affiliated with Logitech, Microsoft or intelliGo.

## References

- Microsoft: [Audio Processing Object Architecture](https://learn.microsoft.com/windows-hardware/drivers/audio/audio-processing-object-architecture)
- Microsoft: [PKEY_CompositeFX_StreamEffectClsid](https://learn.microsoft.com/windows-hardware/drivers/audio/pkey-compositefx-streameffectclsid)
- [Equalizer APO](https://sourceforge.net/projects/equalizerapo/) source code, for how Windows chooses between legacy and newer effect entries
- [Notes on the Loudness Equalization registry values](https://gist.github.com/ThaTiemsz/28671465ec3ee1f690a260fd70699514)

## License

[MIT](LICENSE)
