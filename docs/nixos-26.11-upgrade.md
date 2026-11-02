# NixOS 26.11 upgrade notes

Repository-specific follow-ups for the next release upgrade. Started
2026-11-02; the release migration has not been performed. Add other known
upgrade tasks here as they arise.

## Release inputs and validation

- When the release branches are available, update `nixpkgs` in `flake.nix`
  from `nixos-26.05` to `nixos-26.11` and Home Manager from `release-26.05`
  to `release-26.11`. Review release notes and compatibility of the other
  inputs before updating the lock file.
- Preserve the existing input-follow relationships, including the unstable
  package set following `llm-agents/nixpkgs`, unless deliberately changing
  that arrangement.
- Keep `system.stateVersion` and `home.stateVersion` unchanged as part of
  the routine release upgrade; review any state migrations separately.
- Run `nix flake check --no-build`, build each target before activation,
  and verify services on each upgraded host. For remote hosts, use the
  existing `scripts/check-host-updates.sh --strict` where applicable.

## Desktop: retire the temporary NVIDIA version override

Host: `nixos-2022-desktop` (Z390 DESIGNARE, Intel iGPU, RTX 2070 SUPER).
Configuration:
[`hosts/desktop-z390-9700k/nvidia-rtx2070.nix`](../hosts/desktop-z390-9700k/nvidia-rtx2070.nix).

### Why the override exists

The NixOS 26.05 driver `595.71.05` fails to build against Linux Zen 7.2
because it still calls the removed kernel API `strncpy`. This was reproduced
against the November 2 checkout's Zen `7.2.14`. The host NVIDIA modules had
been disabled to allow system updates while the GPU remained usable through
VFIO.

NVIDIA `615.78.08` builds against that kernel without local source patches.
The temporary `hardware.nvidia.package = ...mkDriver { ... };` block uses
the version and fixed hashes from Nixpkgs' newer driver packaging, while
building with the host's `config.boot.kernelPackages`. The selected package
also supplies the NVIDIA userspace tools, keeping them aligned with the
kernel module.

References:

- [Nixpkgs Linux 7.2 build failure](https://github.com/NixOS/nixpkgs/issues/554125)
- [NVIDIA Linux 7.2 compatibility discussion](https://github.com/NVIDIA/open-gpu-kernel-modules/pull/1227)
- [Nixpkgs newer-driver packaging](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/os-specific/linux/nvidia-x11/default.nix)

### What to remove and retain

When testing 26.11, remove the temporary `hardware.nvidia.package` override
and its explanatory TODO comments, then evaluate the release's default
driver version. Do not assume the new release's default is compatible until
the complete desktop system builds and runtime checks pass. If it fails,
retain or update the override and record why here.

Keep these parts of the desktop configuration:

- `boot.extraModulePackages = lib.mkAfter [config.hardware.nvidia.package.passthru.open];`
  makes the host modules available even though Xorg does not select NVIDIA.
- `hardware.firmware = [config.hardware.nvidia.package.firmware];` supplies
  the matching GSP firmware; the normal NVIDIA module skips this setup when
  NVIDIA is absent from the Xorg driver list.
- `services.xserver.videoDrivers = ["modesetting"];` keeps the Intel iGPU
  driving the host desktop.
- The early VFIO binding and all four GPU PCI IDs in `include/vfio-host.nix`
  retain the default passthrough workflow.
- The conditional/manual NVIDIA CDI generation avoids probing the GPU while
  VFIO owns it.

Remove this NVIDIA follow-up from the pending upgrade work only after:

1. The full desktop system builds with the release-packaged driver, without
   the temporary version/hash block.
2. After activation and a planned reboot, the running kernel matches the
   installed modules, the Intel display works, and the RTX functions still
   bind to VFIO by default.
3. During a planned VM shutdown, native NVIDIA binding works and `nvidia-smi`
   reports the expected driver and GPU, including available temperature,
   power, and fan information. Ensure host clients release the GPU before
   returning it to VFIO, then verify VM passthrough works again.
4. `netconsole-sender` still starts with console threshold 7 and Yoshi
   receives fresh kernel messages. Record the new kernel and driver versions
   in the [freeze investigation](troubleshooting/nixos-2022-desktop-system-freezes.md).

### Verification status before the upgrade

- The standalone `615.78.08` open module built successfully for
  `7.2.14-zen1`; `modinfo` confirmed its version and kernel ABI.
- The complete desktop system with the override and explicit GSP firmware
  built successfully on November 2. The realized system contains the matching
  `615.78.08` module, firmware, and `nvidia-smi`; its kernel parameters retain
  `loglevel=7`. Formatting and whitespace checks passed.
- Evaluation retains the Intel `modesetting` display driver, early VFIO
  binding of all four GPU functions, and manual/conditional CDI generation.
- Activation, post-reboot verification, and native GPU binding checks remain
  pending. The running kernel at preparation time is `7.2.11-zen1`, while the
  current lock builds `7.2.14-zen1`. Stage with `nh os boot -a` and reboot
  during a planned VM shutdown before testing native binding, so the running
  kernel and newly installed modules match.

Restoring host-driver availability is not evidence that the intermittent
freeze is fixed. The passthrough guest uses its own NVIDIA driver while it
owns the GPU; continue recording incidents separately.

## Existing full-flake check failure: Bowser Open WebUI

On November 2, `nix flake check --no-build` reached Bowser and failed because
Open WebUI depends on `python3.14-posthog-7.71.0`, marked broken in the pinned
unstable package set. Evaluating Bowser from untouched commit
`696676ab91943064e802eaa06ebb73be3d5a0637` reproduced the failure, independently
of the desktop NVIDIA changes.

Recheck this dependency when updating the release and unstable inputs. The
complete desktop build succeeds, but the repository-wide check cannot be
marked passed until this separate dependency issue is resolved.
