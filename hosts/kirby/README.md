# kirby

> Dell OptiPlex 7050 Micro (purchased 2023)

## State / Manual Setup Steps
*Things that are not included in the Nix configuration*

### Secrets
- `/root/.ssh/id_ed25519.pub` - root's SSH key
  - `ssh-keygen -t ed25519`
  - Needs to be added to BorgBase
- `/var/lib/secrets/root` - directory that holds secrets that should only be
  readable by the root user
  - Borg passphrases for each repo ([borg-backup.nix](./borg-backup.nix))

### Backups
- BorgBase - repos need to be initialized
  - `borgmatic init -e repokey-blake2`
