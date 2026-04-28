{
  description = "Declarative APT package management for Debian/Ubuntu via Nix + Ansible";

  outputs = { self, ... }: {
    homeManagerModules.default = ./modules/home-manager.nix;
    systemManagerModules.default = ./modules/system-manager.nix;
  };
}
