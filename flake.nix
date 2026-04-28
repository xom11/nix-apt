{
  description = "Declarative APT package management for Debian/Ubuntu via Nix + Ansible";

  outputs = { self }: {
    homeManagerModules = {
      default = ./modules/home-manager.nix;
      nix-apt = ./modules/home-manager.nix;
    };

    systemManagerModules = {
      default = ./modules/system-manager.nix;
      nix-apt = ./modules/system-manager.nix;
    };
  };
}
