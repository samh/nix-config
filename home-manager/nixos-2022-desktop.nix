{pkgs, ...}: {
  imports = [
    ./global
    ./global/sway.nix
    ./global/vscode-with-extensions.nix
  ];

  home.packages = with pkgs; [
    # pkgs.unstable.jetbrains.datagrip
    jetbrains.pycharm
    # pkgs.unstable.jetbrains.pycharm
    # pkgs.unstable.vscode.fhs
  ];

  programs.yazi.enable = true; # terminal file manager
  programs.zoxide.enable = true; # 'cd' replacement
  programs.zsh.enable = true;

  wayland.windowManager.sway.config.output = {
    "DP-2" = {
      mode = "2560x1440@59.951Hz";
      transform = "270";
      position = "0 0";
    };
    "HDMI-A-3" = {
      mode = "2560x1440@59.951Hz";
      transform = "normal";
      position = "1440 560";
    };
  };
}
