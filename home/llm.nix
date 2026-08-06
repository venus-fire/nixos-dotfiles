{ config, pkgs, inputs, ... }:

{
  # little-coder (from our overlay) and the PrismML llama.cpp fork (CPU build,
  # referenced directly from the flake input — not vendored into the repo).
  # The fork is required to load the ternary Q2_0 GGUF; mainline llama.cpp
  # errors on the tensor type.
  #
  # Backend note: the fork's Vulkan build crashes with vk::DeviceLostError on
  # this laptop's Intel Iris Plus (Ice Lake) iGPU under real generation load
  # (server dies mid-request; GGML_VK_DISABLE_F16 didn't help). CPU is stable
  # and ternary Q2 is bandwidth-light, so we use the CPU package. Flip back to
  # `.vulkan` if a newer mesa/llama.cpp fixes the hang.
  home.packages = [
    pkgs.little-coder
    inputs.llama-cpp.packages.${pkgs.system}.default
  ];

  # pi requires SOME value for local-provider API keys even though the local
  # llama-server ignores it (little-coder README: export LLAMACPP_API_KEY=noop).
  home.sessionVariables = {
    LLAMACPP_API_KEY = "noop";
  };

  # Provider/model override. Provider keys fully replace the shipped
  # models.json; the llama-cpp provider points at the local llama-server
  # (PrismML fork) on little-coder's default port 8888.
  xdg.configFile."little-coder/models.json".source = ../config/little-coder/models.json;
}
