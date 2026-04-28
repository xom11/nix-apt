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

### With system-manager (recommended — runs as root, no sudo workaround)

```nix
{
  inputs = {
    nix-apt.url = "github:xom11/nix-apt";
    system-manager.url = "github:numtide/system-manager";
  };

  outputs = { self, system-manager, nix-apt, ... }: {
    systemConfigs.default = system-manager.lib.makeSystemConfig {
      modules = [
        nix-apt.systemManagerModules.default
        ({ ... }: {
          services.nix-apt = {
            enable = true;
            aptPackages = [ "git" "kitty" ];
            debGetPackages = [ "brave-browser" "tailscale" ];
          };
        })
      ];
    };
  };
}
```

Apply: `sudo system-manager switch --flake .`

### With home-manager (works, but needs sudo at activation)

```nix
{
  inputs.nix-apt.url = "github:xom11/nix-apt";

  # In your home.nix:
  imports = [ inputs.nix-apt.homeManagerModules.default ];

  services.nix-apt = {
    enable = true;
    aptPackages = [ "git" ];
    aptRepos = [{
      name = "brave";
      keyUrl = "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg";
      repo = "https://brave-browser-apt-release.s3.brave.com/ stable main";
    }];
    debGetPackages = [ "tailscale" ];
  };
}
```

Run `sudo -v` first to cache credentials, then `home-manager switch`.

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
