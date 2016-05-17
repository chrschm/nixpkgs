{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.flyingcircus;
  fclib = import ../lib;

  mail_out_service = lib.findFirst
    (s: s.service == "mailserver-mailout")
    null
    config.flyingcircus.enc_services;

in
{
  options = {

    flyingcircus.roles.mailserver = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable the Flying Circus mailserver out role and configure
          mailout on all nodes in this RG/location.

          Note: you still need to manually set "myhostname" and make proper
          DNS settings.
        '';
      };

    };
  };

  config = mkIf cfg.roles.mailserver.enable {
    services.postfix.enable = true;

    # Allow all networks on the SRV interface. We expect only trusted machines
    # can reach us there (firewall).
    services.postfix.networks =
      if cfg.enc.parameters.interfaces ? srv
      then builtins.attrNames cfg.enc.parameters.interfaces.srv.networks
      else [];
  };
}
