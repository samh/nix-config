{pkgs, ...}: {
  # The vscode.fhs package makes extensions from the store work (i.e. that
  # have binaries that might otherwise fail) but causes problems with things
  # like podman.
  # One alternative is to declaratively enable extensions as we do here.
  programs.vscode = {
    enable = true;
    #package = pkgs.unstable.vscode;
    #package = pkgs.vscodium;

    profiles.default.extensions =
      (with pkgs.vscode-extensions; [
        bbenoist.nix

        # Python
        ms-python.python
        ms-python.debugpy
        ms-python.vscode-pylance
        charliermarsh.ruff

        # Shell
        #mkhl.shfmt
        foxundermoon.shell-format

        # Containers
        ms-azuretools.vscode-containers # "Container Tools"
        ms-vscode-remote.remote-containers # "Dev Containers"

        # Remote
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-ssh-edit
        #ms-vscode-remote.vscode-remote-extensionpack

        # AI
        #github.copilot
        github.copilot-chat
      ])
      ++ (with pkgs.vscode-marketplace-release; [
        #saoudrizwan.claude-dev # Cline
        #mkhl.shfmt # Shell script formatting
      ]);
  };
}
