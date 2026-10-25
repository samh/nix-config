# nixos-2022-desktop intermittent system freezes

*Authored by Codex with model `gpt-5.6-sol high`.*

## Purpose

This is the living investigation log for intermittent hard freezes on
`nixos-2022-desktop`, the Gigabyte Z390 DESIGNARE system with an Intel Core
i7-9700K.

Update this document after each freeze and after each controlled experiment.
Keep confirmed observations separate from hypotheses. Because freezes may be
months apart, change one relevant variable at a time whenever practical and
record the exact observation period.

The older personal note remains useful as source material:

```text
/home/samh/Notes/Notes-Personal/Home-PCs/
  (2019) Z390 Core i7-9700K/System Hang (Freeze).md
```

## Incident classes

### Long-running hard-freeze problem

This document primarily tracks freezes with all of these characteristics:

- the display remains on but stops updating
- local input stops working
- the host disappears from the network
- the kernel journal contains no final crash signature
- the host remains stuck until a hard reset

This signature has occurred occasionally for years across stock, LTS, XanMod,
and Zen kernels. That history makes a single kernel regression or desktop
environment bug unlikely.

### Separate 2026 envfs incidents

The three freezes on 2026-04-24 followed VS Code/PET failures and had tasks
observably blocked on FUSE `envfs` paths such as `/bin`, `/bin/bin`, and
`/usr/bin/bin`.

Treat those as a separate incident class unless new evidence connects them to
the older silent hard freezes.

## Known hard-freeze incidents

Times are generally when Uptime Kuma declared the host down, not necessarily
the exact first frozen instruction.

| Date and time | Kernel or activity notes |
| --- | --- |
| 2024-01-07 17:43 | No final journal evidence recorded. |
| 2024-01-09 04:12 | No final journal evidence recorded. |
| 2024-02-06 13:50:23 | Booted 2024-01-25 13:47:05. |
| 2024-05-28 21:14 | Happened while opening Wirecutter tabs in Firefox. |
| 2024-09-13 20:34 | No final journal evidence recorded. |
| 2025-01-23 22:40:21 | Linux 6.6.69-xanmod1; Windows 10 VFIO VM had run that day. |
| 2025-03-10 | Linux 6.12.10-zen1. |
| 2025-09-22 | Linux 6.15.11-xanmod1; last retained journal entry was 00:11. |
| 2026-08-10 around 01:37 | Linux 7.1.3-zen2; detailed below. |
| 2026-10-24; Kuma failure reported 21:13:57 EDT | Linux 7.2.10-zen1, BIOS F10; same stuck display, passthrough VM running. First recurrence recalled since update. Last retained local journal entry 21:07:20; next boot 21:31:34. Exact freeze onset unconfirmed. |

This list is incomplete. Absence from the table does not imply the system was
stable throughout the interval.

## 2026-08-10 incident

### Timing

Uptime Kuma recorded this failed check at 01:37:38:

```text
PING 100.64.5.32 (100.64.5.32) 56(84) bytes of data.

--- 100.64.5.32 ping statistics ---
47 packets transmitted, 0 received, 100% packet loss, time 47088ms
```

Depending on whether Kuma timestamps the start or completion of the check,
the host was unreachable by approximately 01:36:51 to 01:37:38.

The last retained journal messages were at 01:32:21. They were periodic Xfce
notification-plugin warnings, not a crash report. Journald uses a five-minute
default sync interval for messages below critical priority, so an abrupt freeze
around 01:37 can explain why the final minutes never reached disk.

There was no orderly shutdown. The next boot at 08:57 found the system and user
journals unclean and replayed journals for several filesystems.

### What was ruled out by the retained logs

No retained event near the freeze showed any of the following:

- an OOM kill or systemd-oomd action
- a kernel panic, soft lockup, hard lockup, or hung-task report
- an Intel i915 GPU hang
- an NVMe timeout, controller reset, or I/O error
- a Btrfs error
- a machine check, AER error, or thermal event
- a suspend, shutdown, or UPS power-transition request
- a virtual-machine or VFIO fault

Current UDisks health data after reboot reported both NVMe controllers live,
with no critical SMART warning and temperatures of approximately 48 and 54
degrees Celsius.

### Nearby scheduled work

The weekly trim ran immediately before the missing journal interval:

```text
01:26:22  fstrim.service started
01:31:10  fstrim.service completed successfully
01:32:21  last retained journal message
around 01:37  host stopped answering Kuma
```

The trim covered the NVMe-backed root, home, Flatpak, VM, and EFI filesystems.
An essentially identical trim completed on 2026-08-03, after which the same
boot continued for another week.

Conclusion: retain `fstrim` as a possible trigger for this particular freeze,
but do not treat it as the general root cause. The older incidents occurred on
varied days, at varied times, and under varied workloads.

## 2026-10-24 incident

### User report and timing

The user reports the same stuck-display behavior as the older freezes, with a
passthrough VM running. This is the first freeze they recall since the
2026-08-10 BIOS update. They describe improved stability but explicitly note
that this could be coincidence. The approximately 75-day calendar interval is
not a continuous-uptime measurement or proof of a reduced failure rate; older
incidents were also separated by months.

Uptime Kuma reported this failed check at 21:13:57 EDT:

```text
PING 100.64.5.32 (100.64.5.32) 56(84) bytes of data.

--- 100.64.5.32 ping statistics ---
47 packets transmitted, 0 received, 100% packet loss, time 47087ms
```

The check lasted about 47 seconds. Its timestamp has not been confirmed as the
start or completion time, so it does not establish the exact freeze onset.

The failed boot began on 2026-10-14 at 13:13:57 EDT, using Linux
`7.2.10-zen1`. Its last retained local journal entry is a routine Tailscale
message at 21:07:20 EDT on October 24, about 6 minutes 37 seconds before the
Kuma timestamp. The next boot began at 21:31:34 EDT, also using
`7.2.10-zen1`. It found unclean system and user journals and replayed filesystem
journals, consistent with an abrupt reset rather than an orderly shutdown.

### Retained evidence

- No retained kernel message identifies a panic, lockup, OOM kill, machine
  check, AER fault, i915 hang, NVMe timeout, or Btrfs error explaining the freeze.
- The last retained kernel messages on October 24 concern a YubiKey input
  device at 10:52:28, not the failure. The GPU-root-port spurious PME warnings
  remain present in the failed boot's startup logs, without a corresponding
  warning near the freeze.
- VFIO GPU resets and KVM messages were recorded on October 23. They establish
  earlier VM activity, but do not identify a VM or GPU fault at the freeze.
- The latest weekly `fstrim` completed successfully on October 19 at 01:43,
  several days before this incident. The August trim proximity did not recur.
- After reboot, DMI still reports F10 and microcode is `0x104`, updated early
  from firmware revision `0xfa`. `vfio_pci.disable_idle_d3` remains `N`.

### Remote capture result and limitation

The desktop's netconsole sender started successfully on October 14 at
13:14:10. Yoshi's continuously running receiver has been active since October
14 at 14:04:03 with zero restarts. It retained desktop kernel messages through
October 23 at 14:15:30, but none on October 24 before the reboot. No remote
crash signature was captured near the Kuma failure time.

After today's reboot, the sender started at 21:31:47 and Yoshi received
extended kernel records at that same time. Boot-time sender startup and
end-to-end reception are therefore verified. Reception yesterday and after
the reboot does not prove delivery was possible at the instant of the freeze.

The failed boot's command line specified `loglevel=4`; after reboot,
`/proc/sys/kernel/printk` reads `4 4 1 7`. At console threshold 4, netconsole
normally transmits levels 0 through 3 (errors and more severe messages),
excluding warnings, notices, and informational messages. The failed boot's
runtime threshold at the instant of the freeze was not recorded. Absence of
remote messages is therefore not evidence that all kernel activity ceased or
that no lower-priority diagnostic was emitted. See the kernel documentation
for [netconsole](https://docs.kernel.org/networking/netconsole.html) and
[console severity filtering](https://docs.kernel.org/core-api/printk-basics.html).

Conclusion: F10 has not eliminated the historical freeze signature. A lower
frequency remains possible but unproven. The active passthrough VM keeps the
VFIO/PCIe hypothesis relevant without establishing causation. Experiment B
below is the previously planned next isolation step; it has not been applied.
Because the VM was running, this incident does not specifically implicate
VFIO's idle-device D3 transitions; device power states at the freeze are unknown.
Broader netconsole severity capture is also worth considering before another
long observation period. No firmware, VFIO, logging, or watchdog setting was
changed during this investigation.

## Pre-update hardware and firmware snapshot

Snapshot taken after the 2026-08-10 08:57 reboot, before the BIOS update:

- motherboard: Gigabyte Z390 DESIGNARE-CF
- BIOS: American Megatrends F7, dated 2019-06-05 by DMI
- CPU: Intel Core i7-9700K, 8 cores, no SMT
- runtime CPU microcode: `0x104`, updated early by Linux from BIOS revision
  `0xb8`
- memory: 64 GiB non-ECC DDR4
- host display: Intel UHD 630 using `i915`
- discrete GPU: Gigabyte RTX 2070 SUPER with all four functions normally bound
  to `vfio-pci`
- primary NVMe: WD Black SN850X 4 TB
- secondary NVMe: SK hynix Gold P31 2 TB
- IOMMU command line: `intel_iommu=on iommu=pt`
- NMI watchdog: enabled
- hard-lockup panic and automatic panic reboot: disabled

No active EDAC memory-controller instance is exposed. Non-ECC memory errors
therefore should not be expected to leave useful corrected-error telemetry.

## Significant PCIe observation

The CPU root port at `0000:00:01.0` leads directly to the RTX 2070 functions at
`0000:01:00.0` through `0000:01:00.3`.

The current boot produced bursts of:

```text
pcieport 0000:00:01.0: PME: Spurious native interrupt!
```

At one observation point, IRQ 123 for `00:01.0` had handled approximately 900
PCIe PME interrupts. Two VFIO-owned GPU functions were runtime-suspended while
two were active. The current `vfio-pci` setting allows idle devices to enter
the PCI D3 low-power state:

```text
disable_idle_d3=N
```

Linux prints the warning after handling a root-port power-management event but
failing to identify a downstream device with matching PME status. This makes
the GPU/root-port/firmware power path a meaningful hypothesis.

It is not yet a demonstrated cause. One burst coincided with PCI inspection,
which may itself have touched a runtime-suspended function. The warning has
also existed without an immediate freeze.

References:

- <https://github.com/torvalds/linux/blob/master/drivers/pci/pcie/pme.c>
- <https://docs.kernel.org/power/pci.html>
- personal note `pcieport PME Spurious native interrupt!.md`

## Post-F10 baseline

The direct F7-to-F10 update completed successfully. The first observed F10
Linux boot began at 2026-08-10 10:14 EDT on Linux 7.1.5-zen1.
The freeze boot used 7.1.3-zen2, so the kernel change is a confounding variable
for this observation period. The history of recurrence across many kernels
still makes F10 the more significant newly introduced variable.

The user loaded **Optimized Defaults** after the update and changed only the
default display output to the Intel iGPU. No other BIOS settings were manually
restored or changed. This is the BIOS-setting baseline for the F10 observation
period; record any later firmware-setting change as a separate experiment.

Verified after boot:

- DMI reports BIOS F10, dated 2023-12-21
- the machine booted through UEFI from the existing NixOS ESP
- `intel_iommu=on iommu=pt` remains on the kernel command line
- DMAR, queued invalidation, and IRQ remapping initialized successfully
- the Intel UHD 630 remains the host display using `i915`
- all four RTX 2070 SUPER functions remain bound to `vfio-pci`
- the GPU root port and four GPU functions remain together in IOMMU group 2
- the active-backup network bond, display manager, Tailscale, and libvirt are
  active

F10 supplies CPU microcode revision `0xfa`; Linux then updates it early to
`0x104`. F7 had supplied only `0xb8` before the same Linux update.

The `00:01.0` spurious PME symptom remains present. The new boot logged 114
warnings between 10:14:14 and 10:16:18. GPU functions 1 and 2 were runtime
suspended, functions 0 and 3 were active, and `vfio_pci.disable_idle_d3`
remained false. The immediately preceding F7 boot logged 152 such warnings.
Inspection can itself provoke power-state activity, so those counts should not
be interpreted as a reliable before-and-after rate comparison. The useful
result is that F10 did not eliminate the warning.

The PCIe warning about failed retraining on `00:1c.4` also appeared under both
F7 and F10. That root port has the empty bus range associated with the board's
Thunderbolt path; it is not the RTX, Ethernet, or either NVMe path.

The system was marked degraded only because `evremap.service` could not find
the disconnected ELECOM Relacon. The same failure occurred on the preceding
F7 boot and is unrelated to the firmware change.

Conclusion at this checkpoint: the update is correctly applied, the required
host and VFIO topology is intact, and there is no identified immediate F10
regression. The long-term freeze observation period begins with this boot.

## Ranked hypotheses

### 1. Platform firmware or power stability

This is currently the leading category because:

- the failure spans many kernels and desktop workloads
- the freeze is system-wide and generally leaves no software signature
- BIOS F7 is from 2019
- Gigabyte BIOS F9 explicitly lists a fix for CPU Vcore and power behavior
- later firmware also changes CPU microcode and platform behavior that the OS
  cannot fully replace

The latest official listing observed during the 2026-08-10 investigation was:

- F9, 2021-11-29: CPU Vcore and power behavior fix, updated microcode, and a
  non-reversible capsule-BIOS transition
- F10, 2024-01-11: newest non-letter-suffixed release
- F11a, 2025-06-11: newer security-motivated release

Official support page:

<https://www.gigabyte.com/Motherboard/Z390-DESIGNARE-rev-10/Support>

### 2. RTX 2070 PCIe or VFIO idle-power transitions

Supporting evidence:

- repeated spurious PME interrupts on the GPU's CPU root port
- mixed active and runtime-suspended functions on one multifunction card
- previous GPU resets have left the device in a bad state
- some freezes happened on days when a VFIO VM had run

Counterevidence and uncertainty:

- no DMAR, VFIO, AER, or PCIe link error was retained before the latest freeze
- PME warnings can occur without a freeze
- a freeze has not yet been reproduced on demand by changing GPU state

### 3. Marginal RAM, PSU, CPU, cabling, or motherboard

This remains plausible for a permanent hard lock with no machine-check record.
The long and irregular intervals make substitution tests slow but valuable.

### Lower-priority hypotheses

- a specific Linux kernel or scheduler flavor
- the desktop environment
- NVMe health or Btrfs corruption
- `fstrim` as the root cause of every historical freeze
- the 2026 VS Code/PET `envfs` problem

## Experiment log

| Start | Experiment | Result | Status |
| --- | --- | --- | --- |
| Before 2024-01 | Linux 6.1 LTS | Freeze recurred. | Completed; did not fix |
| 2024-01-09 | Removed USB add-in card | May have reduced frequency, but freezes continued. | Completed; inconclusive |
| 2024-01-25 | Adjusted VFIO-related kernel settings | Freeze recurred on 2024-02-06. | Completed; did not fix |
| 2024-03 onward | Tried XanMod kernels | Freeze recurred. | Completed; did not fix |
| 2025-01 onward | Tried Zen kernels | Freeze recurred. | Completed; did not fix |
| 2026-08-10 | Reviewed previous boot, storage health, timers, and hardware logs | Confirmed silent hard freeze; no final kernel signature. | Completed |
| 2026-08-10 10:14 | Updated motherboard BIOS directly from F7 to F10; loaded Optimized Defaults and changed only default display output to the iGPU | Initial boot and topology checks passed. User recalls no further freeze until October 24; same stuck-display signature then recurred with a passthrough VM active. A frequency improvement is unproven. | Applied; recurrence after about 75 calendar days |
| 2026-10-24 | Reviewed failed boot and Yoshi's netconsole capture after recurrence | No captured crash signature; post-reboot end-to-end capture verified. Console threshold 4 limits capture severity. VFIO idle D3 remains enabled. | Investigation recorded; no settings changed |
| 2026-10-24 21:54 | Broadened kernel console threshold from 4 to 7 | Warning, notice, and informational probes all received on Yoshi at 21:54:34 EDT. Runtime threshold and default boot entry verified. | Applied; capture verified |

## Controlled experiments

Do not mark the remaining planned experiments as attempted until they are
actually performed.

### A. Update motherboard firmware

Recommended target: **F10**.

Status: **Applied 2026-08-10; freeze recurred 2026-10-24. Possible frequency
improvement remains unproven.**

F10 is the newest non-letter-suffixed release listed for this board. F11a is
newer and contains additional security fixes, but Gigabyte uses letter-suffixed
versions such as `F4a` as examples of beta BIOS releases. For an experiment
whose primary goal is eliminating rare stability failures, prefer the mature
F10 release first.

F10 is newer than F9 and is expected to contain the earlier F9 platform changes,
including the CPU Vcore and power-behavior fix. This is an inference from normal
full-image BIOS versioning; Gigabyte's release notes do not explicitly describe
the updates as cumulative.

#### F10 file identification

The official F10 archive checked on 2026-08-10 was named
`mb_bios_z390-designare_8a1fag0u_f10.zip` and contained only:

```text
Z390DESIGNARE.F10  16777216 bytes
```

Checksums calculated from that official download:

```text
ZIP SHA-256:
5df9e6297c6b1454e01b51fde43b0731b64ee95eeb3776ddfd743e6e539b5051

Z390DESIGNARE.F10 SHA-256:
b72167a938e8f25e2d38aac37c326418f812d3fff7aa974ab68f176c76a6c7f6
```

Gigabyte separately lists `1080` as its short checksum. That is not a
conventional SHA digest and should not be substituted for the hashes above.

The verified F10 archive and extracted image are stored in:

```text
/home/samh/Documents/Z390 motherboard/
```

That directory and `/home/samh/Downloads` also contain the old
`mb_bios_z390-designare_f9j.zip`, a 2021 leftover containing the beta image
`Z390DESI.F9j`. Do not flash F9j for this experiment.

On 2026-08-10, the prepared removable drive was verified as `/dev/sde1`, label
`MC_32GB`, with FAT32 filesystem version. Its top-level
`Z390DESIGNARE.F10` matched the SHA-256 above byte-for-byte. Linux had mounted
the filesystem read-only, but the block device was not hardware write-protected
and the kernel log contained no USB or FAT error. Read-only access is sufficient
for Q-Flash.

#### Before rebooting

1. Verify that the motherboard PCB is marked Z390 DESIGNARE revision 1.0.
2. Confirm the archive and extracted image match the identities above.
3. Format a USB drive as FAT32, extract `Z390DESIGNARE.F10`, and place that
   image in the top level of the drive. Do not merely copy the ZIP.
4. Do not rename the image to `GIGABYTE.bin`; that naming is for a different
   Q-Flash Plus workflow. This board's manual describes regular Q-Flash.
5. Photograph every customized BIOS page, especially:
   - SATA mode and boot order
   - CSM and Secure Boot state
   - initial display output and integrated-graphics settings
   - Intel virtualization and VT-d
   - Above 4G Decoding and Re-Size BAR
   - XMP, CPU voltage, and other performance settings
   - fan curves and power or wake settings
6. Shut down any VM cleanly. Plan to leave the passthrough VM off until the
   post-update IOMMU check is complete.
7. Use reliable AC power and do not start during a storm or when power may be
   interrupted.

#### Flash with Q-Flash

1. Leave the FAT32 USB drive connected and reboot.
2. During POST, repeatedly press `End` to enter Q-Flash directly. The manual
   also permits entering BIOS Setup with `Delete` and launching Q-Flash with
   `F8`, but `End` during POST is the most direct path.
3. Select **Update BIOS** and then select `Z390DESIGNARE.F10` on the USB drive.
4. Before confirming, make sure the utility identifies the image for the
   Z390 DESIGNARE and reports F10. Stop if the model or version does not match.
5. Confirm the update. Do not reset, power off, remove the USB drive, or press
   keys while the erase/write/verify operation is running.
6. Allow all automatic reboots to finish. A longer boot, blank screen, or more
   than one restart can be normal after firmware settings are rebuilt.

Attempt the direct F7-to-F10 update. Do not perform an extra F9 flash unless
Q-Flash or an official instruction explicitly requires it. Account for
Gigabyte's warning that the capsule transition introduced by F9 prevents
returning to earlier versions.

#### First boot after the flash

1. Enter BIOS Setup with `Delete` and confirm that the BIOS version is F10.
2. Choose **Load Optimized Defaults**, then save and re-enter BIOS Setup.
3. Restore only the settings needed to boot NixOS and use the Intel iGPU:
   - preserve the existing SATA mode
   - preserve the existing UEFI/CSM and Secure Boot arrangement
   - select the Intel integrated graphics as the host's initial display
   - enable Intel virtualization and VT-d
4. Initially leave XMP, manual CPU voltage or overclocking, enhanced multicore
   behavior, and Re-Size BAR disabled or at their optimized-default values.
   This makes the firmware update a cleaner stability experiment.
5. Save and boot NixOS. Before starting a passthrough VM, verify the reported
   BIOS version, boot parameters, IOMMU state, device bindings, and IOMMU
   groups.
6. Record the update date, exact settings restored, and the start of the
   observation period in the experiment log.

This was selected as the first experiment because the firmware was old and the
vendor specifically changed CPU power behavior after F7.

### B. Prevent VFIO idle D3

Status: **Not applied. The 2026-10-24 recurrence meets the planned trigger for
considering this experiment.**

If the system freezes after the firmware test, try adding
`disable_idle_d3=1` to the existing `vfio-pci` module options in
`include/vfio-host.nix`.

Expected tradeoff: the unused RTX card may consume more power and run warmer at
idle. This is narrower and more reversible than disabling PCIe power management
globally.

Record whether the spurious PME bursts stop after reboot. Because freezes are
rare, absence of a freeze for a few days is not a meaningful success criterion.

### C. Remove the discrete GPU path

For the strongest PCIe A/B test, physically remove the RTX card and run only on
the Intel iGPU for an extended period. Merely changing the bound driver does not
remove the card, slot, auxiliary-power, and root-port path from the test.

### D. Establish a hardware baseline

- load BIOS defaults and run memory at JEDEC settings without XMP
- run multiple complete MemTest passes over all 64 GiB
- reseat DIMMs and test one matched pair at a time if practical
- reseat the motherboard 24-pin and CPU EPS power connectors
- inspect and reseat GPU auxiliary power
- substitute a known-good PSU if freezes continue without the RTX

## Capture plan for the next freeze

### External checks before resetting

From another LAN host, record separately:

1. ping the LAN address `192.168.5.32`
2. ping the Tailscale address `100.64.5.32`
3. attempt SSH to both addresses
4. record whether switch port link remains up

At the console, record:

1. whether the clock or other screen content is still changing
2. whether Caps Lock or Num Lock LEDs respond
3. whether audio continues
4. whether Magic SysRq responds

Avoid waiting indefinitely if the system is clearly wedged and data integrity
is at risk.

### After reboot

Collect at least:

```bash
journalctl --list-boots
journalctl -b -1 -e --no-pager
journalctl -b -1 -k --no-pager
journalctl -b -1 -p warning..alert --no-pager
last -x -F | head -n 30
```

Also record:

- Kuma's first failed check and first successful check
- the kernel version from the failed boot
- whether a VM had run since the last boot
- whether the GPU had been dynamically rebound
- any recent firmware, kernel, BIOS-setting, RAM, or cabling change
- whether scheduled `fstrim`, garbage collection, backup, or scrub work ran
  shortly before the failure

### Better persistent capture

Decision on 2026-08-10: set up kernel netconsole now, using `yoshi` as the
receiver. This is not premature: the failure is rare and the useful local
journal tail is lost during the freeze, so waiting would risk losing another
months-apart opportunity to capture evidence.

Planned path:

- sender: `nixos-2022-desktop`, LAN address `192.168.5.32`, device `bond0`
- receiver: `yoshi`, LAN address `192.168.5.40`, fixed bond MAC
  `02:00:00:00:00:40`
- transport: kernel netconsole over a dedicated UDP port on the local LAN, not
  over Tailscale
- receiver firewall: accept the UDP port only from `192.168.5.32`
- receiver storage: persistent, separately identifiable netconsole messages
  with bounded retention
- activation: start the sender only after `bond0` is online
- verification: inject a recognizable test message through `/dev/kmsg`, verify
  it on `yoshi`, reboot the sender, and verify capture again
- resilience check: test bond failover separately before relying on it

The current 7.1.5-zen1 kernel provides `CONFIG_NETCONSOLE=m`,
`CONFIG_NETCONSOLE_DYNAMIC=y`, and `CONFIG_NETPOLL=y`. Yoshi is reachable at
the intended LAN address and its configured bond MAC is stable.

Implementation checkpoint on 2026-08-10:

- added `hosts/yoshi/netconsole-receiver.nix`
- added `hosts/desktop-z390-9700k/netconsole-sender.nix`
- the Yoshi receiver listens continuously on UDP port 6666 and writes to its
  persistent journal with identifier `netconsole-nixos-2022-desktop`
- Yoshi's iptables firewall rule accepts that port only on `bond0` and only
  from `192.168.5.32`
- the desktop sender waits for `192.168.5.32` on `bond0`, then loads netconsole
  in extended mode with release tagging and targets Yoshi's fixed bond MAC
- `nix flake check --no-build` passed
- complete Yoshi and desktop system closures built successfully
- Yoshi receiver activation and DNS recovery are verified
- desktop sender activation and end-to-end kernel-message delivery are verified
- both Yoshi and the desktop now have the netconsole configuration in their
  persistent system profiles

The first Yoshi test activation started the initial socket-activated receiver
successfully but was reported as failed because `blocky.service` could not
restart: `systemd-resolved` already owned its loopback DNS stub addresses on
port 53, while Blocky requested wildcard port 53. This was a pre-existing
restart-order conflict exposed by activation, not a netconsole conflict.

The Yoshi-only correction keeps `systemd-resolved` for networkd and Tailscale,
sets `DNSStubListener=no`, and points `/etc/resolv.conf` to
`/run/systemd/resolve/resolv.conf` instead of the disabled stub. The corrected
Yoshi closure and full flake evaluation passed. After repeat activation, Yoshi
reported overall state `running`, Blocky owned TCP and UDP port 53, resolved no
longer exposed the stub, `/etc/resolv.conf` used the uplink file, and the
netconsole socket listened on UDP port 6666. A subsequent boot verified that
the running system and boot profile matched, the receiver returned, the 10 GbE
bond member was active with the 1 GbE member healthy as backup, and DNS still
worked.

A tagged UDP probe reached Yoshi's persistent journal after that reboot. The
probe also showed that the initial socket-activated `cat` collector exited
after one datagram. Although systemd could reactivate it, a kernel-message
burst could hit the service start limit. The receiver was therefore changed to
one continuously running, hardened `socat` process; activation and a burst test
of that revision succeeded. Yoshi received all 50 tagged UDP datagrams in order,
the receiver remained active, and its restart count remained zero.

The desktop sender was test-activated at 10:55 EDT. The service loaded the
`netconsole` module successfully against `bond0`, and the kernel reported
`network logging started`. Yoshi immediately received extended netconsole
records from the desktop, including the `7.1.5-zen1` release, printk sequence
numbers and timestamps, and device metadata. This proves the actual kernel
netconsole path rather than only the receiver's generic UDP path.

Yoshi was then switch-activated. `/run/current-system` and the persistent system
profile both resolved to the same new generation. The receiver remained enabled
and active with zero restarts, the system had no failed units, Blocky and
`systemd-resolved` were active, `bond0` was up, DNS resolved successfully, and a
fresh tagged UDP probe reached the receiver after the switch.

The desktop was made persistent with `nh os boot -a` after the successful test
activation. Generation 256 is the current system profile and the default
systemd-boot entry; its boot entry points to the new system closure and its
`netconsole-sender.service` is identical to the tested unit. The running test
closure and boot-profile closure have no package-level closure differences.
The sender is still active and enabled, and the module remains loaded. The host
reports `degraded` only because the known optional `evremap.service` fails while
the ELECOM Relacon is disconnected. Sender startup and capture after an actual
desktop reboot remained to be verified at the August checkpoint. On
2026-10-24, sender startup and reception on Yoshi after the desktop reboot were
verified; see that incident's remote-capture section above.

Netconsole carries kernel `printk` messages rather than the complete systemd
journal. It is therefore the right first layer for a silent kernel or hardware
failure, but it cannot capture an event that emits no message or a failure that
also prevents the NIC from transmitting. A userspace journal-forwarding layer
could be added later if broader service logs are needed.

Pstore/ramoops is also worth evaluating if a suitable persistent region can be
configured.

### Broader severity capture applied on 2026-10-24

After reviewing the October recurrence, the user agreed to broaden netconsole
capture. `hosts/desktop-z390-9700k/netconsole-sender.nix` now sets
`boot.consoleLogLevel = 7`. This includes levels 0 through 6: warnings,
notices, and informational messages are added to the previous error-level
capture. Debug-level messages remain excluded. The threshold also affects
local kernel consoles.

The pinned NixOS kernel module implements this option both as the boot
parameter `loglevel=7` and the runtime sysctl `kernel.printk = 7`, so switching
to the new generation should take effect without a reboot and persist across
future boots. The sender destination and receiver configuration are unchanged.

The complete desktop closure built successfully. Inspection of its generated
sysctl file and kernel parameters confirmed `kernel.printk=7` and `loglevel=7`.
`nix store diff-closures` found no package-level changes from the active
generation. The sender module passes `alejandra --check`, and
`git diff --check` and the full `nix flake check --no-build` passed.

The user switch-activated the configuration and injected three tagged kernel
messages at 21:54:34 EDT. Yoshi received all three at that same timestamp:
`netconsole-capture-test warning`, `netconsole-capture-test notice`, and
`netconsole-capture-test info`. Their extended records carry consecutive printk
sequence numbers 1295 through 1297, with severity levels 4, 5, and 6.

Live verification confirmed `/proc/sys/kernel/printk` reads `7 4 1 7`, the
sender is active with a successful result, and Yoshi's receiver is active with
zero restarts. The running system and persistent system profile match
generation 264; the default systemd-boot entry for that generation includes
`loglevel=7`. Broader capture is active now and configured for subsequent boots.
No additional reboot was performed for this change.

The NMI watchdog is already active. A later experiment could combine panic on
hard lockup, an automatic panic reboot, and remote or persistent crash capture,
but that changes failure behavior and should be reviewed separately before
enabling it.

## Updating this document

For every new incident:

1. add it to the incident table
2. add a dated subsection if there is meaningful evidence
3. update the experiment log without rewriting earlier results
4. promote or demote hypotheses only when the new evidence warrants it
5. label inferences explicitly

Do not combine an `envfs`-signature incident with the silent hard-freeze series
unless evidence supports that connection.
