{inputs, ...}: {
  imports = [inputs.hermes-agent.nixosModules.default];

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    settings.model = {
      provider = "openai-codex";
      default = "gpt-6.2-sol";
    };

    backend = {
      mode = "dashboard";
      host = "127.0.0.1";
      port = 9119;
    };
  };
}
