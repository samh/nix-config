# From https://github.com/Mic92/dotfiles/blob/main/nixos/modules/nix-ld.nix
# Which was linked from
# https://blog.thalheim.io/2022/12/31/nix-ld-a-clean-solution-for-issues-with-pre-compiled-executables-on-nixos/
{pkgs, ...}: {
  # Enable nix ld
  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    fuse3
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    curl
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libGL
    libappindicator-gtk3
    libdrm
    libnotify
    libpulseaudio
    libuuid
    libusb1
    libxcb
    libxkbcommon
    mesa
    nspr
    nss
    pango
    pipewire
    systemd
    icu
    openssl
    libx11
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxkbfile
    libxshmfence
    zlib
  ];
}
