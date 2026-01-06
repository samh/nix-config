# NUT UPS config for this host.
{...}: let
  upsName = "cp1500pfclcd";
in {
  imports = [
    ../include/power-ups.nix
  ];

  power.ups.ups.${upsName} = {
    driver = "usbhid-ups";
    port = "auto";
    description = "CyberPower CP1500PFCLCD";
  };

  power.ups.upsmon.monitor.${upsName} = {
    user = "upsmon";
  };
}
