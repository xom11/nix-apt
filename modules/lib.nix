{ lib, pkgs }: {
  optionsAttrs = {
    aptPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "APT packages to install via `apt install`.";
      example = [ "git" "vim" "kitty" ];
    };

    aptRepos = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Identifier for keyring filename and sources.list filename.";
          };
          keyUrl = lib.mkOption {
            type = lib.types.str;
            description = "URL to GPG keyring file (binary .gpg or armored .asc).";
          };
          repo = lib.mkOption {
            type = lib.types.str;
            description = ''
              APT source line excluding the leading `deb [signed-by=...] ` part.
              Example: `https://brave-browser-apt-release.s3.brave.com/ stable main`.
            '';
          };
        };
      });
      default = [ ];
      description = "Third-party APT repositories with GPG keys (modern signed-by format).";
    };

    debUrls = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Direct .deb URLs to install via apt.";
      example = [ "https://example.com/some-app_1.0_amd64.deb" ];
    };

    debGetPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Packages installed via deb-get (https://github.com/wimpysworld/deb-get).
        deb-get is bootstrapped automatically if absent.
        Run `deb-get list` to see available recipes.
      '';
      example = [ "brave-browser" "tailscale" "code" ];
    };
  };

  mkPlaybook = cfg:
    let
      needAptUpdate =
        cfg.aptPackages != [ ] || cfg.debUrls != [ ] || cfg.aptRepos != [ ];

      ensureKeyringsDir = lib.optional (cfg.aptRepos != [ ]) {
        name = "Ensure /etc/apt/keyrings";
        "ansible.builtin.file" = {
          path = "/etc/apt/keyrings";
          state = "directory";
          mode = "0755";
        };
      };

      downloadKeys = map (r: {
        name = "Keyring: ${r.name}";
        "ansible.builtin.get_url" = {
          url = r.keyUrl;
          dest = "/etc/apt/keyrings/${r.name}.gpg";
          mode = "0644";
          force = false;
        };
      }) cfg.aptRepos;

      addRepos = map (r: {
        name = "Source: ${r.name}";
        "ansible.builtin.apt_repository" = {
          repo = "deb [signed-by=/etc/apt/keyrings/${r.name}.gpg] ${r.repo}";
          filename = r.name;
          state = "present";
          update_cache = false;
        };
      }) cfg.aptRepos;

      aptUpdate = lib.optional needAptUpdate {
        name = "Update apt cache";
        "ansible.builtin.apt" = {
          update_cache = true;
          cache_valid_time = 3600;
        };
      };

      installApt = lib.optional (cfg.aptPackages != [ ]) {
        name = "Install apt packages";
        "ansible.builtin.apt" = {
          name = cfg.aptPackages;
          state = "present";
        };
      };

      installDebs = map (url: {
        name = "Install .deb: ${url}";
        "ansible.builtin.apt" = { deb = url; };
      }) cfg.debUrls;

      bootstrapDebGet = lib.optional (cfg.debGetPackages != [ ]) {
        name = "Bootstrap deb-get";
        "ansible.builtin.shell" =
          "curl -sL https://raw.githubusercontent.com/wimpysworld/deb-get/main/deb-get | bash -s install deb-get";
        args = { creates = "/usr/bin/deb-get"; };
      };

      installDebGet = map (pkg: {
        name = "deb-get: ${pkg}";
        "ansible.builtin.command" = { cmd = "deb-get install -y ${pkg}"; };
      }) cfg.debGetPackages;

      tasks = ensureKeyringsDir ++ downloadKeys ++ addRepos ++ aptUpdate
        ++ installApt ++ installDebs ++ bootstrapDebGet ++ installDebGet;
    in
    pkgs.writeText "nix-apt-playbook.yml" (builtins.toJSON [{
      name = "nix-apt declarative bootstrap";
      hosts = "localhost";
      connection = "local";
      become = true;
      gather_facts = false;
      inherit tasks;
    }]);

  hasWork = cfg:
    cfg.aptPackages != [ ] || cfg.aptRepos != [ ] || cfg.debUrls != [ ]
    || cfg.debGetPackages != [ ];
}
