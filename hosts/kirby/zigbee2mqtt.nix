{
  config,
  lib,
  pkgs,
  ...
}: let
  zigbee2mqttPort = 8099;
in {
  services.zigbee2mqtt = {
    enable = true;

    # https://www.zigbee2mqtt.io/guide/configuration/
    settings = {
      # Let new devices join our zigbee network
      # > It's important that permit_join is set to false in your configuration.yaml
      # > after initial setup is done to keep your Zigbee network safe and to avoid
      # > accidental joining of other Zigbee devices.
      # https://www.zigbee2mqtt.io/guide/configuration/zigbee-network.html#permit-join
      # Should be able to enable temporarily via frontend!
      permit_join = false;

      homeassistant = false;

      # https://www.zigbee2mqtt.io/guide/configuration/frontend.html
      frontend = {
        port = zigbee2mqttPort;
        auth_token = "!secret.yaml auth_token";
      };

      # https://www.zigbee2mqtt.io/guide/configuration/zigbee-network.html
      advanced = {
        # My home WiFi is currently just on channel 6 for 2.4 GHz.
        # Some neighbors are on channels 1 and 11.
        # Zigbee channel 25, to the right of WiFi channel 11,
        # seems like it should be the safest.
        #
        # See:
        # https://www.zigbee2mqtt.io/advanced/zigbee/02_improve_network_range_and_stability.html
        channel = 25;
      };
      mqtt = {
        # MQTT base topic for Zigbee2MQTT MQTT messages
        base_topic = "zigbee2mqtt";
        # MQTT server URL
        server = "mqtt://127.0.0.1:1883";
        user = "zigbee2mqtt";
        # Set password by the environment variable ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD
        # or by a separate file.
        #password = "zigbee2mqtt";
        password = "!secret.yaml mqtt_password";
      };
      serial = {
        port = "/dev/serial/by-id/usb-Silicon_Labs_slae.sh_cc2652rb_stick_-_slaesh_s_iot_stuff_00_12_4B_00_25_9B_6C_0A-if00-port0";
      };
    };
  };
  services.nginx.virtualHosts."zigbee2mqtt" = {
    serverName = "zigbee2mqtt.${config.local.hostDomain}";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString zigbee2mqttPort}";
      proxyWebsockets = true;
      extraConfig = ''
        # https://www.zigbee2mqtt.io/guide/configuration/frontend.html#nginx-proxy-configuration
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      '';
    };
    forceSSL = true;
    useACMEHost = config.local.hostDomain;
  };

  # Use an environment file to set the password.
  # https://www.zigbee2mqtt.io/guide/configuration/#environment-variables
  # Should contain:
  # ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD="mypassword"
  # Could also use a separate file; see
  # https://www.zigbee2mqtt.io/guide/configuration/mqtt.html
  #systemd.services.zigbee2mqtt.serviceConfig.EnvironmentFile = lib.mkDefault "/root/zigbee2mqtt.env";
}
