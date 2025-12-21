{pkgs, ...}: {
  imports = [
    ./global
    ./global/vscode-with-extensions.nix
  ];

  home.packages = with pkgs; [
    pkgs.unstable.jetbrains.pycharm
    # pkgs.unstable.vscode.fhs
  ];
}
