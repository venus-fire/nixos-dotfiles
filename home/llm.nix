{ config, pkgs, pkgs-unstable, lib, inputs, ... }:

{
  # little-coder (from our overlay) + mainline llama.cpp with the Vulkan
  # backend, pulled from nixpkgs-unstable (b10133). The ternary Bonsai model
  # was abandoned: its Q2_0 Vulkan kernels (new upstream code) produced
  # garbage on this laptop's Intel Iris Plus iGPU regardless of flags.
  # Standard quant types (Q3_K_M etc.) use the mature, well-tested kernels.
  #
  # Model: Qwen3-30B-A3B (MoE, ~3B active params) Q3_K_M — llama.cpp mmaps
  # the GGUF and streams only the active experts from disk, so a 14.8G file
  # runs fine on this laptop's ~11.6G RAM.
  home.packages = [
    pkgs.little-coder
    pkgs-unstable.llama-cpp-vulkan
  ];

  # pi requires SOME value for local-provider API keys even though the local
  # llama-server ignores it (little-coder README: export LLAMACPP_API_KEY=noop).
  home.sessionVariables = {
    LLAMACPP_API_KEY = "noop";
  };

  # Provider/model override. Provider keys fully replace the shipped
  # models.json; the llama-cpp provider points at the local llama-server on
  # little-coder's default port 8888.
  xdg.configFile."little-coder/models.json".source = ../config/little-coder/models.json;

  # Serve the Qwen3-30B-A3B MoE model on 127.0.0.1:8888 with the Vulkan
  # backend. Conservative flags learned from the ternary saga:
  #   - -np 1: single slot (multi-slot decode triggered device-lost crashes)
  #   - --flash-attn off: flash-attn on this old iGPU was a crash suspect
  #   - --cache-ram 2048: 2G prompt-cache budget — reuse for repeated prompts
  #     without the ~8G default reservation that caused memory pressure
  # User service so it has GPU access and the model path under /home/venus.
  systemd.user.services.llama-server = {
    Unit = {
      Description = "llama-server (mainline llama.cpp, Vulkan) — Qwen3-30B-A3B Q3_K_M";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.concatStringsSep " " [
        "${pkgs-unstable.llama-cpp-vulkan}/bin/llama-server"
        "-m /home/venus/models/Qwen3-30B-A3B-Instruct-2507.Q3_K_M.gguf"
        "--host 127.0.0.1 --port 8888 -c 16384 --jinja -ngl 99 --cpu-moe -np 1 --flash-attn off --cache-ram 2048"
      ];
      Restart = "on-failure";
      RestartSec = "5";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
