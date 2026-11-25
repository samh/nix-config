{inputs, ...}: {
  imports = [inputs.hermes-agent.nixosModules.default];

  services.hermes-agent.enable = true;
}
