{ config, pkgs, pkgs-unstable, lib, inputs, ... }:

{
  # little-coder (from our overlay) + mainline llama.cpp with the Vulkan
  # backend, pulled from nixpkgs-unstable (b10133). The ternary Bonsai model
  # was abandoned: its Q2_0 Vulkan kernels (new upstream code) produced
  # garbage on this laptop's Intel Iris Plus iGPU regardless of flags.
  # Standard quant types (Q3_K_M etc.) use the mature, well-tested kernels.
  #
  # 2026-08-11 model trials (replacing the 30B MoE that was too slow):
  #
  # Candidate 1: Qwen2.5-Coder-1.5B-Instruct Q8_0 — dense, fast (57 tok/s
  #   prompt, 9.7 tok/s gen), but 1.5B is weak for complex coding.
  # Candidate 2: Qwen3.5-4B-Super-Coder Q4_0 — GDN hybrid, 1.2 tok/s prompt
  #   (GDN on CPU), unusably slow.
  # Candidate 3 (current): LFM2.5-2.6B Q5_K_M — Liquid hybrid architecture,
  #   7.4 tok/s prompt, 10.2 tok/s gen. Fast enough, 2.6B params.
  #   The 30B MoE models were deleted from disk to free ~26 GB.
  #
  # Previous MoE/crash history preserved below for reference:
  #
  # Qwen3-Coder-30B-A3B (Q3_K_S) was tried (2026-08-09): same qwen3moe arch,
  # but it crashes with GGML_ASSERT(id >= 0 && id < n_expert) at
  # ggml-backend.cpp:1615 — open upstream bug #25777 (Vulkan MoE-offload
  # expert-id read-back race, no fix as of b10333), which then leaves the
  # GPU in a DeviceLost state until reboot. The general Qwen3-30B checkpoint
  # does NOT trip this race (4.5h uptime, same flags). Revisit Coder only
  # after #25777 is fixed upstream.
  #
  # Qwen3.6-35B-A3B (GatedDeltaNet hybrid) was also tried (2026-08-09):
  # unusable on this hardware. GDN has immature kernels: CPU-only tg16 =
  # 0.05 t/s, Vulkan + cpu-moe tg ~0.2 t/s (llama.cpp issues #26795/#21888
  # class). MTP (--spec-type draft-mtp) never even activated.
  #
  # 2026-08-09 landmine documented: the unit used to point at
  # /home/venus/models/Qwen3-30B-A3B-Instruct-2507.Q3_K_M.gguf but that file
  # had been moved to the big-one drive, leaving ~/models empty. The old
  # service only kept running because it held the file mmap'd; any restart
  # would have failed. Resolution: active model lives in ~/models again
  # (user preference, fast NVMe); the old Qwen3-30B general model stays on
  # big-one as a backup.
  home.packages = [
    pkgs.little-coder
    pkgs-unstable.llama-cpp-vulkan
  ];

  # pi requires SOME value for local-provider API keys even though the local
  # llama-server ignores it (little-coder README: export LLAMACPP_API_KEY=noop).
  # LITTLE_CODER_PERMISSION_MODE=accept-all disables the built-in whitelist
  # gate; safety net is the denylist user extension at
  # ~/.config/little-coder/extensions/denylist.mjs (rm, sudo, dd, mkfs, ...).
  home.sessionVariables = {
    LLAMACPP_API_KEY = "noop";
    LITTLE_CODER_PERMISSION_MODE = "accept-all";
  };

  # Provider/model override. Provider keys fully replace the shipped
  # models.json; the llama-cpp provider points at the local llama-server on
  # little-coder's default port 8888.
  xdg.configFile."little-coder/models.json".source = ../config/little-coder/models.json;

  # Serve the LFM2.5-2.6B Q5_K_M on 127.0.0.1:8888 with the Vulkan
  # backend. Liquid hybrid architecture — runs well on this laptop's Intel
  # Iris Plus iGPU (7.4 tok/s prompt, 10.2 tok/s gen). Uses a thinking/
  # reasoning mode (reasoning_content in responses).
  #   - -ngl 99: offload all layers (1.81 GB Q5_K_M, fits easily)
  #   - -c 32768: 32K context
  #   - --flash-attn on: beneficial
  #   - -np 1: single slot
  #   - --cache-ram 1024: 1G prompt-cache budget
  # User service so it has GPU access and the model path under /home/venus.
  systemd.user.services.llama-server = {
    Unit = {
      Description = "llama-server (mainline llama.cpp, Vulkan) — LFM2.5-2.6B Q5_K_M";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.concatStringsSep " " [
        "${pkgs-unstable.llama-cpp-vulkan}/bin/llama-server"
        "-m /home/venus/models/LFM2.5-2.6B-Q5_K_M.gguf"
        "--host 127.0.0.1 --port 8888 -c 32768 --jinja -ngl 99 -np 1 --flash-attn on --cache-ram 1024"
      ];
      Restart = "on-failure";
      RestartSec = "5";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
