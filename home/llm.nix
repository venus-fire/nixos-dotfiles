# little-coder + llama.cpp service. Gated by `config.llm.enable` (set in
# ./default.nix): when false this module contributes nothing (server unit,
# package installs, env vars, pi/little-coder config all vanish), so the box
# keeps building but stops serving — no commenting out.
{ config, pkgs, pkgs-unstable, lib, inputs, ... }:

{
  config = lib.mkIf config.llm.enable {
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
    # Candidate 3: LFM2.5-2.6B Q5_K_M — Liquid hybrid, 7.4/10.2 tok/s, decent.
    # Candidate 4: MiniCPM5-1B-Claude-Opus-Fable5-V2-Thinking Q8_0 —
    #   Llama architecture, 67.7/15.5 tok/s. Thinking built in. Works but
    #   user issues with it.
    # Candidate 5: MiniCPM5-1B-Agentic-Tooluse-v3 Q8_0 — kept thinking
    #   endlessly instead of answering.
    # Candidate 6: LFM2.5-1.2B-Nova-Function-Calling Q5_K_M —
    #   Liquid architecture, fine-tuned for function calling. No thinking
    #   mode. 17.6 tok/s prompt, 22.9 tok/s gen.
    # Candidate 7: LFM2.5-2.6B Q5_K_M — stronger for coding than the 1.2B.
    #   Reasoning left ON (user preference); model thinks in reasoning_content.
    #
    # Candidate 8: LFM2.5-8B-A1B Q4_K_M — TRIED and SCRAPPED (2026-08-18).
    #   Loads and mlock's fine (8K ctx, pinned RAM), but its Vulkan decode hard
    #   crashes this laptop's Intel Iris Plus Gen11 iGPU on EVERY generation:
    #   vk::DeviceLostError, i915 "GPU HANG", then core dump. Reproduced across
    #   several restarts, after a reboot, AND with the fp32 kernel fallback
    #   (GGML_VK_DISABLE_F16=1). The 2.6B runs the same flags no problem, so
    #   this is a genuine incompatibility between the 8B-A1B's decode and this
    #   old GPU. Scrapped per user instruction. The Q4_K_M file (~/models) is
    #   kept on disk in case a future llama.cpp/GPU change revives it.
    # Candidate 7 (current, reverted 2026-08-18): LFM2.5-2.6B Q5_K_M.
    #   Now served with --load-mode mlock (pinned in RAM, no swap) -- inherits
    #   the LimitMEMLOCK=infinity + PAM memlock-unlimited setup added for the 8B.
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

    # pi (Earendil coding agent, 0.75.4) — same local llama-server. pi reads
    # ~/.pi/agent/models.json (reloaded each time /model is opened).
    # NOTE: the home-manager `programs.pi-coding-agent` module is master-only;
    # our locked release-26.05 home-manager predates it, so we manage the file
    # directly (identical target path/JSON the option would write).
    #   - apiKey "noop": dummy — llama-server ignores auth (pi requires SOME key
    #     for the model to be selectable in /model).
    #   - compat.supportsDeveloperRole=false / supportsReasoningEffort=false:
    #     plain system role; llama.cpp ignores reasoning_effort anyway, and
    #     the model still reasons on its own (reasoning: true above).
    home.file.".pi/agent/models.json".text = builtins.toJSON {
      providers = {
        llamacpp = {
          baseUrl = "http://127.0.0.1:8888/v1";
          api = "openai-completions";
          apiKey = "noop";
          compat = {
            supportsDeveloperRole = false;
            supportsReasoningEffort = false;
          };
          models = [
            {
              id = "lfm2.5-2.6b";
              name = "LFM2.5-2.6B Q5_K_M";
              reasoning = true;
              input = [ "text" ];
              contextWindow = 32768;
              maxTokens = 4096;
              cost = {
                input = 0;
                output = 0;
                cacheRead = 0;
                cacheWrite = 0;
              };
            }
          ];
        };
      };
    };

    # Serve the LFM2.5-2.6B Q5_K_M on 127.0.0.1:8888 with the Vulkan backend.
    # Liquid hybrid architecture — runs well on this laptop's Intel Iris Plus
    # iGPU. Uses a thinking/reasoning mode (reasoning_content in responses);
    # left ON (user preference, 2026-08-15).
    #   - -ngl 99: offload all layers (1.81 GB Q5_K_M, fits easily)
    #   - -c 32768: 32K context
    #   - --load-mode mlock: mmap + pin weights resident in RAM so the kernel
    #     never swaps the model out. Works now that the user manager inherits a
    #     huge memlock cap (PAM loginLimits + LimitMEMLOCK=infinity in this unit;
    #     added 2026-08-18 when the 8B's mlock was blocked by the 64 KiB default).
    #   - --flash-attn on: beneficial
    #   - -np 1: single slot
    #   - --cache-ram 1024: 1G prompt-cache budget
    # User service so it has GPU access and the model path under /home/venus.
    systemd.user.services.llama-server = {
      Unit = {
        Description = "llama-server (mainline llama.cpp, Vulkan) — LFM2.5-2.6B Q5_K_M (mlock'd)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.concatStringsSep " " [
          "${pkgs-unstable.llama-cpp-vulkan}/bin/llama-server"
          "-m /home/venus/models/LFM2.5-2.6B-Q5_K_M.gguf"
          "--host 127.0.0.1 --port 8888 -c 32768 --load-mode mlock --jinja -ngl 99 -np 1 --flash-attn on --cache-ram 1024"
        ];
        Restart = "on-failure";
        RestartSec = "5";
        # mlock needs to pin the model weights in RAM; the default
        # RLIMIT_MEMLOCK for user processes (64 KiB) blocks that, so raise it
        # to infinity. Without this llama-server logs
        # "failed to mlock ... Cannot allocate memory. Try increasing
        # RLIMIT_MEMLOCK ('ulimit -l' as root)" and the model pages to swap.
        LimitMEMLOCK = "infinity";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
