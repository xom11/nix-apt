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

      echo "[nix-apt] applying: ${myLib.mkSummary cfg}"
      export PATH="/usr/bin:/bin:$PATH"
      export ANSIBLE_BECOME_EXE="/usr/bin/sudo"
      export ANSIBLE_PYTHON_INTERPRETER="/usr/bin/python3"
      output=$(${pkgs.ansible}/bin/ansible-playbook -i localhost, ${playbook} 2>&1)
      status=$?
      if [ $status -ne 0 ]; then
        echo "$output" | sed 's/^/  /'
        exit $status
      fi
      recap=$(echo "$output" | grep -oE 'ok=[0-9]+ +changed=[0-9]+ +unreachable=[0-9]+ +failed=[0-9]+' | head -1)
      echo "[nix-apt] $recap"
    '';
  };
}
