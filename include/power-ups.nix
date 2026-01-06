{config, ...}: {
  power.ups = {
    enable = true;
    mode = "standalone";

    users.upsmon = {
      passwordFile = config.sops.secrets."ups/upsmon_password".path;
      upsmon = "primary";
    };
  };

  sops.secrets."ups/upsmon_password" = {};
}
