# prime-agent — RLM coding agent (PrimeIntellect)
#
# The CLI itself comes from the overlay (pkgs/prime-agent, release-tarball
# packaging — see pkgs/prime-agent.nix). The Python kernel it drives its agent
# with comes from pkgs/prime-agent-kernel (ipykernel + bundled prime-agent-runtime
# + bundled skills).
#
# The bin on PATH is a small wrapper that exports PRIME_AGENT_KERNEL_PYTHON
# before exec'ing the real binary. This guarantees prime-agent uses the Nix
# kernel env NO MATTER how it is launched — without it, a shell that predates
# the switch (or never sourced the new .zshenv) lacks the var and prime-agent
# falls back to its own uv bootstrap into $HOME ("uv is required to set up the
# Python kernel"). The sessionVariable below is belt-and-braces for anything
# that spawns prime-agent outside the wrapper.
#
# Config/auth/sessions land in ~/.prime/agent/ at runtime (not managed here).
{ pkgs, ... }:

let
  # Single source of truth for the kernel Python path — used both by the
  # wrapper script AND the session variable, so they stay in sync.
  kernelPython = "${pkgs.prime-agent-kernel}/bin/python3.12";

  prime-agent = pkgs.writeShellScriptBin "prime-agent" ''
    export PRIME_AGENT_KERNEL_PYTHON="${kernelPython}"
    exec "${pkgs.prime-agent}/bin/prime-agent" "$@"
  '';
in
{
  home.packages = [ prime-agent ];

  # Belt-and-braces: processes that bypass the wrapper (e.g. spawned from
  # a shell that hasn't sourced the wrapper) still see the right kernel.
  home.sessionVariables.PRIME_AGENT_KERNEL_PYTHON = kernelPython;
}
