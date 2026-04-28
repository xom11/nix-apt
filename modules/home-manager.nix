{ config, lib, pkgs, ... }:
let
  myLib = import ./lib.nix { inherit lib pkgs; };
  cfg = config.services.nix-apt;
  playbook = myLib.mkPlaybook cfg;
in {
  options.services.nix-apt = myLib.optionsAttrs // {
    enable = lib.mkEnableOption "nix-apt declarative apt management (home-manager backend)";
  };

  config = lib.mkIf (cfg.enable && myLib.hasWork cfg) {
    home.activation.nix-apt = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x /usr/bin/apt-get ]; then
        echo "[nix-apt] apt-get not found, skipping (not Debian/Ubuntu)"
        exit 0
      fi

      if ! /usr/bin/sudo -n true 2>/dev/null; then
        echo "[nix-apt] sudo credentials needed"
        /usr/bin/sudo -v || { echo "[nix-apt] sudo failed, aborting"; exit 1; }
      fi

      echo "[nix-apt] running ansible playbook..."
      export PATH="/usr/bin:/bin:$PATH"
      export ANSIBLE_BECOME_EXE="/usr/bin/sudo"
      export ANSIBLE_PYTHON_INTERPRETER="/usr/bin/python3"
      ${pkgs.ansible}/bin/ansible-playbook \
        -i localhost, \
        ${playbook}
    '';
  };
}
