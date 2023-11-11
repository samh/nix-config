{pkgs, ...}: {
  imports = [
    ./global
  ];

  home.packages = with pkgs; [
    pkgs.unstable.vscode.fhs
  ];
}
