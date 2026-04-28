# nix-apt

Declarative APT package management for Debian/Ubuntu via Nix + Ansible.

> **Status: BETA** — single maintainer, dogfooded on Ubuntu 26.04.

## When NOT to use

- You are on **NixOS** — use `environment.systemPackages` directly.
- You are on **macOS** — use [nix-homebrew](https://github.com/zhaofengli/nix-homebrew).
- You need **reproducible** package versions — APT cannot pin reliably.
- You need **rollback** — APT is not atomic.
- You need **GC of removed packages** — nix-apt does NOT auto-uninstall (cascading removal is unsafe in apt).

## What it does

Bridges Nix declarative config to Ansible playbook execution. Supports four input lists:

| Option | Use for |
|---|---|
| `aptPackages` | Plain `apt install` from Ubuntu repos |
| `aptRepos` | Third-party APT repos with GPG keys (modern signed-by format) |
| `debUrls` | Direct .deb URLs (e.g. GitHub release assets) |
| `debGetPackages` | Wraps [deb-get](https://github.com/wimpysworld/deb-get) — 600+ recipes (Brave, Tailscale, VSCode, Docker, etc.) |

## Quick start

Two complete copy-pasteable flake examples in [`examples/`](./examples):

- [`examples/system-manager/`](./examples/system-manager/) — recommended, runs as root via systemd
- [`examples/home-manager/`](./examples/home-manager/) — works, prompts sudo at activation

### Minimal usage (system-manager)

```nix
{
  inputs.nix-apt.url = "github:xom11/nix-apt";
  inputs.system-manager.url = "github:numtide/system-manager";

  outputs = { system-manager, nix-apt, ... }: {
    systemConfigs.default = system-manager.lib.makeSystemConfig {
      modules = [
        nix-apt.systemManagerModules.default
        {
          system-manager.allowAnyDistro = true;
          services.nix-apt = {
            enable = true;
            aptPackages = [ "git" "kitty" ];
            debGetPackages = [ "brave-browser" "tailscale" ];
          };
        }
      ];
    };
  };
}
```

Apply: `sudo system-manager switch --flake .`

### Minimal usage (home-manager)

```nix
imports = [ inputs.nix-apt.homeManagerModules.default ];

services.nix-apt = {
  enable = true;
  aptPackages = [ "git" ];
  debGetPackages = [ "tailscale" ];
};
```

Run `sudo -v` first to cache credentials, then `home-manager switch`.

## Notes on `aptRepos`

- `keyUrl` should point to a **binary GPG keyring** (`.gpg`). Ansible's `get_url` does NOT
  convert ASCII-armored `.asc` keys. If the upstream only ships `.asc`, download once and
  rehost, or convert with `gpg --dearmor`.
- `repo` is the source line **excluding** the leading `deb [signed-by=...] ` part —
  nix-apt prepends that automatically using `/etc/apt/keyrings/<name>.gpg`.
- `name` is used as both keyring filename and `sources.list.d/<name>.list` filename — keep it short and stable.

## Notes on `debUrls`

- nix-apt does **not** auto-detect architecture. Pick the URL that matches your machine
  (`amd64` for x86_64, `arm64` for aarch64). A wrong-arch URL fails with
  `Wrong architecture 'amd64' -- Run dpkg --add-architecture to add it`.
- Use direct release-asset URLs that don't redirect mid-download. GitHub release URLs
  using `/releases/download/...` work fine.
- Each URL becomes a separate Ansible task — failures stop the rest of the playbook.

## Notes on `debGetPackages`

- Only Ubuntu/Debian releases supported by [deb-get itself](https://github.com/wimpysworld/deb-get)
  will work — typically current LTS + the latest stable. Pre-release or non-LTS versions
  (e.g. Ubuntu 26.04 "Resolute" before deb-get adds support) will fail with
  `ERROR! Ubuntu <codename> is not supported`.
- Run `deb-get list` once to confirm the recipe name (e.g. `code` for VSCode, not `vscode`;
  `brave-browser` not `brave`).
- nix-apt bootstraps deb-get itself by piping the upstream install script through `bash`
  with the `creates: /usr/bin/deb-get` Ansible guard — re-runs are no-ops.

## How it works

1. Nix evaluates `services.nix-apt.*` options.
2. `mkPlaybook` generates an Ansible playbook (JSON, valid YAML 1.2 superset) into `/nix/store`.
3. On activation: `ansible-playbook -c local -i localhost, /nix/store/.../nix-apt-playbook.yml`.
4. Ansible's `apt`, `apt_repository`, `get_url` modules handle GPG keys, repo files, install — idempotent.

The dependency `pkgs.ansible` (~150MB) is added to the closure when `enable = true`.

## Backend selection

| Backend | Privilege | Workaround | Best for |
|---|---|---|---|
| `systemManagerModules.default` | Root via systemd | None | Ubuntu hosts with system-manager |
| `homeManagerModules.default` | User + sudo prompt | PATH + `ANSIBLE_BECOME_EXE` | Existing home-manager-only setups |

Both share the same options API and playbook generation logic.

## License

MIT

## Acknowledgments

- Pattern inspired by [nix-flatpak](https://github.com/gmodena/nix-flatpak).
- Recipe registry: [deb-get](https://github.com/wimpysworld/deb-get) by Martin Wimpress.
- Built on [Ansible](https://www.ansible.com/) `ansible.builtin.*` modules.
