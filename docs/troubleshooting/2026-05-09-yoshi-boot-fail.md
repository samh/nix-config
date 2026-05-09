# 2026-05-09: yoshi boot failure

*Written by Copilot GPT-5.4.*

## Summary

`yoshi` had multiple failed boots on 2026-05-09 that appeared as a black
screen and never reached SSH. The issue was diagnosed as a NixOS configuration
problem, not an obvious hardware failure.

The failing boots dropped into emergency mode because a boot-critical bind mount
for the NFS export `Retro` ran before the underlying storage was ready.

## Affected boots

Recent boot history at the time of investigation:

- `-3` at `2026-05-09 12:16` - failed
- `-2` at `2026-05-09 12:26` - successful
- `-1` at `2026-05-09 12:29` - failed

## Symptoms

- Local display stayed black
- Host never became reachable over SSH
- One boot in between succeeded, making the issue look intermittent

## Diagnosis

The logs for the failed boots showed:

```text
Failed to mount /srv/nfs/Retro.
Dependency failed for Local File Systems.
local-fs.target: Job local-fs.target/start failed with result 'dependency'.
Reached target Emergency Mode.
```

The relevant Nix config on `yoshi` exported `Retro` through an NFSv4
pseudo-root by bind mounting:

```nix
fileSystems."/srv/nfs/Retro" = {
  device = "/storage/Games/Retro";
  options = ["bind"];
};
```

At the same time, `/storage` is a `mergerfs` mount built from `/media/disk*`.
Those backing mounts use `nofail`, so they are not all guaranteed to be ready
before `local-fs.target` continues.

That created a race:

1. `/storage` could mount before the backing branch that actually contained
   `Games/Retro`.
2. systemd then attempted to bind mount `/storage/Games/Retro` into
   `/srv/nfs/Retro`.
3. If the path did not exist yet in the merged view, the bind mount failed.
4. Because this mount was part of normal local filesystem boot, the failure
   caused `local-fs.target` to fail and the machine entered emergency mode.

This explains why the machine never reached the normal boot path for SSH or the
graphical session.

## Why it was intermittent

The merged path depended on branch availability timing. At the time of the
investigation:

- `/media/disk3/Games/Retro` contained the real data
- `/media/disk4.4TB.raid1/Games/Retro` existed but was empty

So whether `/storage/Games/Retro` existed early enough depended on when the
relevant mergerfs branches became visible during boot.

## Why this did not look like hardware failure

Warnings from NVIDIA, ACPI, and other subsystems appeared on both successful and
failed boots. The strongest boot-blocking signal was the filesystem dependency
failure around `/srv/nfs/Retro`, not a consistent hardware initialization
failure.

## Proposed remediation

Do not make the `Retro` bind mount part of boot-critical `local-fs.target`.
Instead, mount it after local filesystems and `/storage` are available, just
before starting the NFS server.

That approach avoids:

- blocking the whole boot if `Retro` is temporarily unavailable
- relying on mergerfs branch timing during early boot
- assuming the data permanently lives on any one specific physical disk

## Config change proposed to fix it

The `hosts/yoshi/nfs.nix` config was updated to stop declaring
`/srv/nfs/Retro` as a normal `fileSystems` entry.

Instead, it now uses a dedicated `systemd.mounts` entry:

```nix
systemd.mounts = [
  {
    description = "Bind Retro into the NFSv4 export tree";
    what = "/storage/Games/Retro";
    where = "${nfs_root}/Retro";
    type = "none";
    options = "bind,nofail";
    after = [
      "local-fs.target"
      "storage.mount"
    ];
    wants = ["storage.mount"];
    before = ["nfs-server.service"];
    wantedBy = ["nfs-server.service"];
    unitConfig.ConditionPathExists = "/storage/Games/Retro";
  }
];
```

### Why this change was chosen

- It keeps the bind mount declarative as a real systemd mount unit.
- It removes the bind mount from the boot-critical `local-fs.target` path.
- It still starts the mount automatically when `nfs-server.service` starts.
- It waits until local filesystems and the `mergerfs` storage mount are up.
- `ConditionPathExists` and `nofail` make a missing `Retro` path non-fatal to
  the rest of the boot.

### Alternative considered and rejected

An earlier idea was to bind mount from the real backing path on
`/media/disk3/Games/Retro` instead of the merged `/storage` path. That was not
kept because the data should not be assumed to live permanently on one specific
physical disk.
