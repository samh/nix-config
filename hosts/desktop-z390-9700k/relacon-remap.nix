{pkgs, ...}: {
  # Remap Relacon trackball media buttons to arrow keys
  # (this is the handheld remote trackball, with USB receiver)
  #
  # The Relacon trackball has "media back/forward" buttons that send
  # KEY_PREVIOUSSONG and KEY_NEXTSONG events. These don't work with
  # YouTube or most applications, so we remap them to arrow keys.
  #
  # The device appears as two input devices:
  # - event2 (/dev/input/event2): Mouse movements and basic clicks
  # - event3 (/dev/input/event3): Extra buttons (media controls)
  #
  # The "phys" parameter ensures we grab the correct device (input1)
  # which has the keyboard events including the media buttons.
  #
  # To debug or reconfigure:
  # - List devices: cat /proc/bus/input/devices | grep -A 10 Relacon
  # - Monitor events: nix-shell -p evtest --run "evtest /dev/input/event3"
  # - Check service: systemctl status evremap.service
  # - View logs: journalctl -u evremap.service
  services.evremap = {
    enable = true;
    settings = {
      device_name = "ELECOM ELECOM Relacon";
      phys = "usb-0000:00:14.0-12.4/input1";
      remap = [
        {
          input = ["KEY_PREVIOUSSONG"];
          output = ["KEY_LEFT"];
        }
        {
          input = ["KEY_NEXTSONG"];
          output = ["KEY_RIGHT"];
        }
      ];
    };
  };
}
