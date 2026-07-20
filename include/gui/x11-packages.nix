# Shared X11 packages for use across desktop environments
# Import this file and splice the list into environment.systemPackages
{pkgs}:
with pkgs; [
  xhost
  xclip
  xsel
]
