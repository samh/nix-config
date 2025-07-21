{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.ollama;
in {
  options = {
    my.ollama = {
      enable = lib.mkEnableOption "Enable Ollama LLM server";
      openFirewallTailscale =
        lib.mkEnableOption
        "Open firewall over Tailscale (no auth!); make sure to set services.ollama.host";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.ollama = {
        enable = true;
        # acceleration = "cuda";
        # package = pkgs.unstable.ollama-cuda;
        # host = "0.0.0.0";
        environmentVariables = {
          # https://github.com/ollama/ollama/blob/main/docs/faq.md
          # "Flash Attention is a feature of most modern models that can
          # significantly reduce memory usage as the context size grows"
          OLLAMA_FLASH_ATTENTION = "1";
          # "The K/V context cache can be quantized to significantly reduce
          # memory usage when Flash Attention is enabled"
          # "How much the cache quantization impacts the model's response
          # quality will depend on the model and the task. Models that have
          # a high GQA count (e.g. Qwen2) may see a larger impact on
          # precision from quantization than models with a low GQA count."
          # "You may need to experiment with different quantization types
          # to find the best balance between memory usage and quality."
          # Options: f16 (default), q8_0, q4_0
          OLLAMA_KV_CACHE_TYPE = "q8_0";
        };
      };
    })
    (lib.mkIf (cfg.enable && cfg.openFirewallTailscale) {
      # Allow ollama over tailscale
      # WARNING: does not have any authentication
      networking.firewall.interfaces.tailscale0 = {
        allowedTCPPorts = [config.services.ollama.port];
      };
    })
  ];
}
