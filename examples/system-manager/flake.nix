{
  description = "nix-apt example: system-manager backend (recommended, runs as root)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    system-manager.url = "github:numtide/system-manager";
    system-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-apt.url = "github:xom11/nix-apt";
  };

  outputs = { self, system-manager, nix-apt, ... }: {
    systemConfigs.default = system-manager.lib.makeSystemConfig {
      modules = [
        nix-apt.systemManagerModules.default
        ({ ... }: {
          system-manager.allowAnyDistro = true;

          services.nix-apt = {
            enable = true;

            aptPackages = [ "git" "vim" "kitty" ];

            aptRepos = [{
              name = "brave";
              keyUrl = "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg";
              repo = "https://brave-browser-apt-release.s3.brave.com/ stable main";
            }];

            debUrls = [
              # Pin a specific .deb if you need version control:
              # "https://github.com/sharkdp/bat/releases/download/v0.24.0/bat_0.24.0_amd64.deb"
            ];

            debGetPackages = [
              "brave-browser"
              "tailscale"
              "code"
            ];
          };
        })
      ];
    };
  };
}
