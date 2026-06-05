{pkgs, ...}: {
  imports = [
    ./global
    #./global/vscode-with-extensions.nix
  ];

  home.packages = with pkgs; [
    jetbrains.pycharm
    # pkgs.unstable.jetbrains.pycharm
    # pkgs.unstable.vscode.fhs
  ];
}
