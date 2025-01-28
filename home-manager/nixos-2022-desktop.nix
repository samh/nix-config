{pkgs, ...}: {
  imports = [
    ./global
  ];

  home.packages = with pkgs; [
    # pkgs.unstable.jetbrains.datagrip
    pkgs.unstable.jetbrains.pycharm-professional
    pkgs.unstable.vscode.fhs
  ];

  programs.yazi.enable = true; # terminal file manager
  programs.zoxide.enable = true; # 'cd' replacement
  programs.zsh.enable = true;
}
