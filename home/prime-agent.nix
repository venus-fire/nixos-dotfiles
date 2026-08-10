# prime-agent — RLM coding agent (PrimeIntellect)
#
# The CLI itself comes from the overlay (pkgs/prime-agent, release-tarball
# packaging — see pkgs/prime-agent.nix). The Python kernel it drives its agent
# with comes from pkgs/prime-agent-kernel (ipykernel + bundled prime-agent-runtime
# + bundled skills), wired in via PRIME_AGENT_KERNEL_PYTHON so the agent skips
# its own uv/venv bootstrap and never writes a kernel env into $HOME.
#
# Config/auth/sessions land in ~/.prime/agent/ at runtime (not managed here).
{ pkgs, ... }:

{
  home.packages = [ pkgs.prime-agent ];

  home.sessionVariables.PRIME_AGENT_KERNEL_PYTHON =
    "${pkgs.prime-agent-kernel}/bin/python3.12";
}
