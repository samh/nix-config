{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.local.common;
in {
  options.local.common.ansible = {
    enable = mkEnableOption "Ansible controller";
  };

  config = mkIf cfg.ansible.enable {
    environment.systemPackages = with pkgs; [
      ansible
      libsecret # provides secret-tool
    ];
  };
}
