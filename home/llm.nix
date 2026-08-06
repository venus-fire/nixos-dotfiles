{ config, pkgs, pkgs-unstable, lib, inputs, ... }:

{
  # little-coder (from our overlay) + mainline llama.cpp with the Vulkan
  # backend, pulled from nixpkgs-unstable (the stable 26.05 llama-cpp predates
  # the ternary Q2_0 merge upstream; the PrismML fork's own Vulkan kernels
  # crash with vk::DeviceLostError on this laptop's Intel Iris Plus iGPU).
  # Mainline merged ternary support (CPU/Metal/Vulkan/CUDA) in July 2026, and
  # its Vulkan kernels are the mature, upstream-reviewed ones. The ternary
  # model file must be the g64 variant (group size 64) — the mainline format.
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

  # Serve the Ternary Bonsai 8B (Q2_0 g64) model on 127.0.0.1:8888 with the
  # Vulkan backend (all layers offloaded). User service so it has GPU access
  # and the model path under /home/venus.
  #
  # GGML_VK_DISABLE_F16=1 is REQUIRED on this laptop: the ternary Q2_0 fp16
  # decode kernels hang the Intel Iris Plus (Ice Lake) iGPU with
  # vk::DeviceLostError (reproduced on both the PrismML fork and mainline
  # llama.cpp; prefill works, decode dies). The fp32 kernels are stable.
  systemd.user.services.llama-server = {
    Unit = {
      Description = "llama-server (mainline llama.cpp, Vulkan) — Ternary Bonsai 8B Q2_0 g64";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.concatStringsSep " " [
        "${pkgs-unstable.llama-cpp-vulkan}/bin/llama-server"
        "-m /home/venus/models/Ternary-Bonsai-8B-Q2_0_g64.gguf"
        "--host 127.0.0.1 --port 8888 -c 16384 --jinja -ngl 99"
      ];
      Environment = [ "GGML_VK_DISABLE_F16=1" ];
      Restart = "on-failure";
      RestartSec = "5";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
