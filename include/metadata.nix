# There doesn't seem to be an obvious way that people store "data"
# in their nix configs. This one is based on
# https://github.com/Xe/nixos-configs.git
# (see ops/metadata/hosts.toml and peers.nix)
# I'm trying to take the idea of storing the data in a TOML file,
# but then make it available in `config`. I'm not sure if this is
# better or worse than Xe's approach of calling
# "metadata = pkgs.callPackage ../../../ops/metadata/peers.nix { };"
# everywhere it is used.
{
  config,
  lib,
  ...
}: let
  metadata = lib.importTOML ./metadata.toml;
in {
  options.my.metadata = lib.mkOption {
    type = lib.types.attrs;
    default = metadata;
    description = "Data about hosts, network, etc.";
  };
}
