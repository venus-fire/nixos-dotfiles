# prime-agent Python kernel environment
#
# prime-agent drives its agent through a persistent IPython kernel. At startup it
# checks PRIME_AGENT_KERNEL_PYTHON (see home/prime-agent.nix) and, if that python
# has everything, skips its own auto-bootstrap (which would otherwise download
# uv + Python 3.11 into $HOME and pip-install there). The requirements, straight
# from the bundled runtime check (dist/bundle/chunk-*.js):
#   * ipykernel
#   * prime-agent-runtime  — the `rlm` shim, bundled in the npm tarball at
#     dist/prime-agent-runtime (pure-python, hatchling)
#   * "default Python packages": requests, httpx, pyyaml, tomli, python-dotenv,
#     pandas, numpy, scipy, beautifulsoup4, lxml, pydantic, tyro  (+ dill for
#     state snapshots)
#   * the bundled Python skills from dist/skills/*/pyproject.toml (compact, goal,
#     edit, refine, websearch, ...) — without them prime-agent warns and disables
#     those skills. They are tiny pure-python hatchling packages, built below.
#
# NOTE: python312, NOT the upstream-pinned 3.11 — nixpkgs 26.05 cannot build
# python311's ipython (sphinx 9.1.0 dropped py3.11; typeguard 4.4.4 still pulls
# sphinxHook, blowing up any env that forces ipython's closure). The agent's
# kernel check imports ipykernel/rlm only — no version assert — and the runtime
# requires-python is >= 3.10, so 3.12 is equivalent here.
#
# The src for the runtime and each skill is the installed prime-agent package's
# own output (single source of truth for version + hashes — no duplicate fetches).
{ lib, python312, python312Packages, prime-agent }:

let
  # Installed layout of buildNpmPackage: $out/lib/node_modules/<name>/...
  bundled = "${prime-agent}/lib/node_modules/prime-agent/dist";

  # tyro 1.0.13 isn't in the binary cache for this nixpkgs pin, so its full
  # test suite runs locally — and 2 bash-completion tests fail in the sandbox
  # (4326 pass; file-completion markers, environment-specific). Skip the suite.
  tyro = python312Packages.tyro.overridePythonAttrs (old: {
    doCheck = false;
  });

  mkSkill = { name, deps ? [ ] }: python312Packages.buildPythonPackage {
    pname = "prime-agent-skill-${name}";
    version = "0.1.0";
    src = "${bundled}/skills/${name}";
    format = "pyproject";
    nativeBuildInputs = [ python312Packages.hatchling ];
    propagatedBuildInputs = deps;
  };

  # Same, but for skills whose source lives in this repo (pkgs/<name>) instead
  # of the bundled dist — e.g. custom integrations like tavily.
  mkLocalSkill = { name, deps ? [ ] }: python312Packages.buildPythonPackage {
    pname = "prime-agent-skill-${name}";
    version = "0.1.0";
    src = ./prime-agent-skill-${name};
    format = "pyproject";
    nativeBuildInputs = [ python312Packages.hatchling ];
    propagatedBuildInputs = deps;
  };

  primeAgentRuntime = python312Packages.buildPythonPackage {
    pname = "prime-agent-runtime";
    version = "0.1.0";
    src = "${bundled}/prime-agent-runtime";
    format = "pyproject";
    nativeBuildInputs = [ python312Packages.hatchling ];
    propagatedBuildInputs = [
      python312Packages.ipykernel
      python312Packages.nest-asyncio
      tyro
    ];
  };

  # deps mirror each skill's pyproject.toml `dependencies` (v0.7.1)
  skills = [
    (mkSkill { name = "agent-message"; })
    (mkSkill { name = "agent-observe"; })
    (mkSkill { name = "attach-image"; deps = [ python312Packages.pillow primeAgentRuntime ]; })
    (mkSkill { name = "compact"; })
    (mkSkill { name = "edit"; })
    (mkSkill { name = "goal"; })
    (mkSkill { name = "linear"; deps = [ python312Packages.mcp python312Packages.httpx primeAgentRuntime ]; })
    (mkSkill { name = "notion"; deps = [ python312Packages.mcp python312Packages.httpx primeAgentRuntime ]; })
    (mkSkill { name = "refine"; })
    (mkSkill { name = "rlm-heartbeat"; })
    (mkSkill { name = "websearch"; deps = [ python312Packages.httpx primeAgentRuntime ]; })
    (mkLocalSkill { name = "tavily"; deps = [ python312Packages.mcp python312Packages.httpx primeAgentRuntime ]; })
  ];
in
python312.withPackages (ps: [
  # kernel base
  ps.ipykernel
  ps.dill
  # default RLM extra packages (DEFAULT_RLM_EXTRA_PACKAGES)
  ps.requests
  ps.httpx
  ps.pyyaml
  ps.tomli
  ps.python-dotenv
  ps.pandas
  ps.numpy
  ps.scipy
  ps.beautifulsoup4
  ps.lxml
  ps.pydantic
  tyro
  primeAgentRuntime
] ++ skills)
