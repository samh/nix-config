{pkgs, ...}: {
  imports = [
    ./global
  ];

  home.packages = with pkgs; [
    pkgs.unstable.jetbrains.pycharm-professional
    pkgs.unstable.vscode.fhs
  ];
}
