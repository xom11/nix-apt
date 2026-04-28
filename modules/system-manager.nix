{ config, lib, pkgs, ... }:
let
  myLib = import ./lib.nix { inherit lib pkgs; };
  cfg = config.services.nix-apt;
  playbook = myLib.mkPlaybook cfg;
in {
  options.services.nix-apt = myLib.optionsAttrs // {
    enable = lib.mkEnableOption "nix-apt declarative apt management (system-manager backend, runs as root)";
  };

  config = lib.mkIf (cfg.enable && myLib.hasWork cfg) {
    systemd.services.nix-apt = {
      description = "nix-apt declarative apt bootstrap";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = [ "/usr/bin" "/bin" "/usr/sbin" "/sbin" ];

      environment = {
        ANSIBLE_PYTHON_INTERPRETER = "/usr/bin/python3";
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.ansible}/bin/ansible-playbook -i localhost, ${playbook}";
      };
    };
  };
}
