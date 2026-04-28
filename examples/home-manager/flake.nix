{
  description = "nix-apt example: home-manager backend (uses sudo prompt)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-apt.url = "github:xom11/nix-apt";
  };

  outputs = { self, nixpkgs, home-manager, nix-apt, ... }: {
    homeConfigurations."myuser" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        nix-apt.homeManagerModules.default
        ({ ... }: {
          home.username = "myuser";
          home.homeDirectory = "/home/myuser";
          home.stateVersion = "25.11";

          services.nix-apt = {
            enable = true;

            aptPackages = [ "git" "vim" "kitty" ];

            aptRepos = [{
              name = "brave";
              keyUrl = "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg";
              repo = "https://brave-browser-apt-release.s3.brave.com/ stable main";
            }];

            debGetPackages = [
              "tailscale"
              "code"
            ];
          };
        })
      ];
    };
  };
}
