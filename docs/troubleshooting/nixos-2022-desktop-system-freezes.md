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

## Current hardware and firmware snapshot

Snapshot taken after the 2026-08-10 reboot:

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

## Proposed controlled experiments

Do not mark these as attempted until they are actually performed.

### A. Update motherboard firmware

Recommended target: **F10**.

F10 is the newest non-letter-suffixed release listed for this board. F11a is
newer and contains additional security fixes, but Gigabyte uses letter-suffixed
versions such as `F4a` as examples of beta BIOS releases. For an experiment
whose primary goal is eliminating rare stability failures, prefer the mature
F10 release first.

F10 is newer than F9 and is expected to contain the earlier F9 platform changes,
including the CPU Vcore and power-behavior fix. This is an inference from normal
full-image BIOS versioning; Gigabyte's release notes do not explicitly describe
the updates as cumulative.

1. Verify the physical motherboard revision before downloading firmware.
2. Record or photograph all current BIOS settings.
3. Download F10 only from the official support page and verify the listed
   checksum (`1080`).
4. Use the firmware's Q-Flash utility. Attempt the direct F7-to-F10 update;
   avoid an extra F9 flash unless Q-Flash or official instructions require it.
5. Account for Gigabyte's warning that the capsule transition introduced by F9
   prevents returning to earlier versions.
6. After flashing, load optimized defaults.
7. Initially leave XMP, overclocking, and enhanced multicore behavior disabled.
8. Re-enable only the settings required for the host, including VT-d and the
   intended iGPU/VFIO arrangement.
9. Revalidate IOMMU groups before starting a passthrough VM.

This should be the first experiment because the firmware is old and the vendor
specifically changed CPU power behavior after F7.

### B. Prevent VFIO idle D3

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

Kernel netconsole to another local machine is the most promising next
observability improvement. It can preserve kernel messages that never reach the
local journal. Pstore/ramoops is also worth evaluating if a suitable persistent
region can be configured.

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
