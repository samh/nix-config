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
    #
    # For secrets we can either include from a separate file
    # (see https://www.zigbee2mqtt.io/guide/configuration/mqtt.html)
    # or use environment variables.
    # (see https://www.zigbee2mqtt.io/guide/configuration/#environment-variables)
    settings = {
      # Join should not be enabled here in the configuration; it can be enabled
      # temporarily via the frontend GUI, or via MQTT.
      # See https://www.zigbee2mqtt.io/guide/usage/pairing_devices.html
      #
      # > It's important that permit_join is set to false in your configuration.yaml
      # > after initial setup is done to keep your Zigbee network safe and to avoid
      # > accidental joining of other Zigbee devices.
      # https://www.zigbee2mqtt.io/guide/configuration/zigbee-network.html#permit-join
      permit_join = false;

      homeassistant = {
        # I'm not entirely clear on what these are for, but 'legacy' sounds
        # like something we should avoid when setting up something new.
        legacy_entity_attributes = false;
        legacy_triggers = false;
      };

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
    };
    forceSSL = true;
    useACMEHost = config.local.hostDomain;
  };
}
