{ config, lib, pkgs, ... }:
let
  myLib = import ./lib.nix { inherit lib pkgs; };
  cfg = config.services.nix-apt;
  playbook = myLib.mkPlaybook cfg;
  runner = myLib.mkRunner cfg playbook;
in {
  options.services.nix-apt = myLib.optionsAttrs // {
    enable = lib.mkEnableOption "nix-apt declarative apt management (home-manager backend)";
  };

  config = lib.mkIf (cfg.enable && myLib.hasWork cfg) {
    home.activation.nix-apt = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x /usr/bin/apt-get ]; then exit 0; fi

      if ! /usr/bin/sudo -n true 2>/dev/null; then
        echo "[nix-apt] sudo credentials needed"
        /usr/bin/sudo -v || { echo "[nix-apt] sudo failed, aborting"; exit 1; }
      fi

      export PATH="/usr/bin:/bin:$PATH"
      export ANSIBLE_BECOME_EXE="/usr/bin/sudo"
      export ANSIBLE_PYTHON_INTERPRETER="/usr/bin/python3"
      ${runner}
    '';
  };
}
