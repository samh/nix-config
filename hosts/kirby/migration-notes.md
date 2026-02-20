# Kirby Migration Notes

Date started: 2026-02-20

## Goal
Move host `kirby` from the current Dell OptiPlex 7050 Micro
(Intel Core i5-6600T) to a newer Dell MFF, Dell OptiPlex 3080 Micro
(Intel Core i5-10500T).

Likely plan:
- Move the current 1TB NVMe into the new box (as the primary drive).
- Move the new box's 256GB NVMe into the old box.

## Current Assumptions In Config
- Boot loader: GRUB on EFI (`hosts/kirby/configuration.nix`).
- Root/boot/swap are pinned by UUID (`hosts/kirby/mounts.nix`), so moving the same 1TB NVMe should preserve mounts.
- Hostname remains `kirby`.
- Network stack is `systemd-networkd` with static LAN IP from metadata (`192.168.5.50`).
- Static route/DNS:
  - Gateway: `192.168.5.1`
  - DNS: `192.168.10.10`, then `192.168.5.50` (local Blocky second)
- A GRUB specialisation `rescue-dhcp` exists for break-glass DHCP boot on unknown networks.
- Metadata expects `kirby` at `192.168.5.50` and `100.64.5.50` (Tailscale).
- Blocky binds DNS to `127.0.0.1`, metadata LAN IP, and metadata Tailscale IP.

## Current Live Status (Verified 2026-02-20)
- `systemd-networkd`: enabled + active
- `NetworkManager`: inactive/not used
- LAN address: `192.168.5.50/24`
- Default route: `via 192.168.5.1`
- Effective resolver order on `en*`: `192.168.10.10`, `192.168.5.50`
- `blocky`: active
- GRUB includes `rescue-dhcp` entry

## Key Migration Risks
1. EFI boot entry may not exist in new motherboard NVRAM.
2. Interface name could differ on new hardware.
3. Static LAN config may not route on a different subnet until using `rescue-dhcp`.
4. If new machine is not Intel, `kvm-intel`/Intel microcode settings should be updated.

## Static IP + Recovery Design
- Default boot: static IPv4 via `systemd-networkd`, matching `en*`.
- Recovery boot: `specialisation.rescue-dhcp` overrides network config to DHCP on `en*`.
- In rescue mode, Blocky is disabled to avoid binding to static metadata IPs.

### Rebuild To Install Specialisation Boot Entry
```bash
sudo nixos-rebuild boot --flake /etc/nixos#kirby
```

### Recovery Flow On Unknown Network
1. Connect local monitor/keyboard.
2. In GRUB, choose `rescue-dhcp` specialisation entry.
3. Confirm obtained address and routing:
   ```bash
   ip -br addr
   ip route
   ```
4. SSH in and adjust normal static networking/metadata if needed.
5. Rebuild, then reboot into normal (non-rescue) entry.

## Suggested Cutover Checklist
1. Pre-move backup/snapshot and confirm remote access path (Tailscale/local console).
2. Install 1TB NVMe in new Dell MFF.
3. Set BIOS to UEFI and confirm boot order points to NixOS EFI entry.
4. Boot once with local monitor/keyboard available.
5. Verify LAN IP, Tailscale, and key services (`nginx`, `blocky`, `samba`, `postgresql`, `forgejo`, `gitea`).
6. Run `nixos-rebuild switch` on new hardware and re-check service health.
7. Validate DNS behavior from a LAN client (`kirby`, `kirby.hartsfield.xyz`, `ha.hartsfield.xyz`, etc.).

## Optional: Rename LVM VG (`dell7050` -> `kirby`)
Current root/swap mounts are UUID-based, so VG rename is mostly cosmetic.

Recommended process (with local console available):
1. Confirm current names:
   ```bash
   sudo vgs
   sudo lvs
   ```
2. Rename VG:
   ```bash
   sudo vgrename dell7050 kirby
   ```
3. Rebuild boot config:
   ```bash
   sudo nixos-rebuild boot --flake /etc/nixos#kirby
   ```
4. Reboot and verify:
   ```bash
   lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,MOUNTPOINTS
   sudo vgs
   sudo lvs
   systemctl --failed
   ```

If anything looks wrong after rename, boot previous generation from GRUB and investigate before switching again.

## Notes / To Decide
- Keep metadata host IP aligned with static network address.
- Consider adding a second rescue specialisation for Wi-Fi/USB ethernet if needed later.
