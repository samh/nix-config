{pkgs, ...}: {
  imports = [
    ./global
    ./global/vscode-with-extensions.nix
  ];

  home.packages = with pkgs; [
    pkgs.unstable.jetbrains.pycharm-professional
    # pkgs.unstable.vscode.fhs
  ];
}
