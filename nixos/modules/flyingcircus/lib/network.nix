/*
 * generic networking functions for use in all of the flyingcircus Nix stuff
 */

{ lib }:

with builtins;
rec {
  stripNetmask = cidr: elemAt (lib.splitString "/" cidr) 0;

  prefixLength = cidr: lib.toInt (elemAt (lib.splitString "/" cidr) 1);

  # The same as prefixLength, but returns a string not an int
  prefix = cidr: elemAt (lib.splitString "/" cidr) 1;

  isIp4 = cidr: length (lib.splitString "." cidr) == 4;

  isIp6 = cidr: length (lib.splitString ":" cidr) > 1;

  # choose the correct iptables version for addr
  iptables = addr: if isIp4 addr then "iptables" else "ip6tables";

  # choose correct "ip" invocation depending on addr
  ip' = addr: "ip " + (if isIp4 addr then "-4" else "-6");

  # list IP addresses for service configuration (e.g. nginx)
  listenAddresses = config: interface:
    if interface == "lo"
    # lo isn't part of the enc. Hard code it here.
    then [ "127.0.0.1" "::1" ]
    else
      if hasAttr interface config.networking.interfaces
      then
        let
          interface_config = getAttr interface config.networking.interfaces;
        in
          (map (addr: addr.address) interface_config.ip4) ++
          (map (addr: addr.address) interface_config.ip6)
      else [];

  /*
   * policy routing
   */

  dev = vlan: bridged: if bridged then "br${vlan}" else "eth${vlan}";

  # VLANS with prio < 100 are generally routable to the outside.
  routingPriorities = {
    fe = 50;
    srv = 60;
    mgm = 90;
  };

  routingPriority = vlan:
    if hasAttr vlan routingPriorities
    then routingPriorities.${vlan}
    else 100;

  # transforms ENC "networks" data structure into an NixOS "interface" option
  # for all nets that satisfy `pred`
  # {
  #   "172.30.3.0/24" = [ "172.30.3.66" ... ];
  #   ...;
  # }
  # =>
  # [ { address = "172.30.3.66"; prefixLength = "24"; } ... ];
  ipAddressesOption = pred: networks:
    let
      transformAddrs = net: addrs:
        map
          (a: { address = a; prefixLength = prefixLength net; })
          addrs;
      relevantNetworks = lib.filterAttrs (net: val: pred net) networks;
    in
    lib.concatMap
      (n: transformAddrs n networks.${n})
      (attrNames relevantNetworks);

  # ENC networks to NixOS option for both address families
  interfaceConfig = networks:
    { ip4 = ipAddressesOption isIp4 networks;
      ip6 = ipAddressesOption isIp6 networks;
    };

  # Collects a complete list of configured addresses from all networks.
  # Each address is suffixed with the netmask from its network.
  allInterfaceAddresses = networks:
    let
      addrsWithNetmask = net: addrs:
        let p = prefix net;
        in map (addr: addr + "/" + p) addrs;
    in lib.concatLists (lib.mapAttrsToList addrsWithNetmask networks);

  # IP policy rules for a single VLAN.
  # Expects a VLAN name and an ENC "interfaces" data structure. Expected keys:
  # mac, networks, bridged, gateways.
  ipRules = vlan: encInterface: filteredNets: verb:
    let
      prio = routingPriority vlan;
      common = "table ${vlan} priority ${toString prio}";
      fromRules = lib.concatMapStringsSep "\n"
        (a: "${ip' a} rule ${verb} from ${a} ${common}")
        (allInterfaceAddresses encInterface.networks);
      toRules = lib.concatMapStringsSep "\n"
        (n: "${ip' n} rule ${verb} to ${n} ${common}")
        filteredNets;
    in
    "\n# policy rules for ${vlan}\n${fromRules}\n${toRules}\n";

  # Routes for an individual VLAN on an interface. This falls apart into two
  # blocks: (1) subnet routes for all subnets on which the interface has at
  # least one address configured; (2) gateway (default) routes for each subnet
  # where any subnet of the same AF has at least one address.
  ipRoutes = vlan: encInterface: filteredNets: verb:
    let
      prio = routingPriority vlan;
      dev' = dev vlan encInterface.bridged;

      networkRoutesStr = lib.concatMapStrings
        (net: ''
          ${ip' net} route ${verb} ${net} dev ${dev'} metric ${toString prio} table ${vlan}
        '')
        filteredNets;

      # A list of default gateways from a list of networks in CIDR form.
      gateways = filteredNets:
        foldl'
          (acc: cidr:
            if hasAttr cidr encInterface.gateways
            then acc ++ [encInterface.gateways.${cidr}]
            else acc)
          []
          filteredNets;

      common = "dev ${dev'} metric ${toString prio}";
      gatewayRoutesStr = lib.optionalString
        (100 > routingPriority vlan)
        (lib.concatMapStrings
          (gw:
          ''
            ${ip' gw} route ${verb} default via ${gw} ${common}
            ${ip' gw} route ${verb} default via ${gw} ${common} table ${vlan}
          '')
          (gateways filteredNets));
    in
    "\n# routes for ${vlan}\n${networkRoutesStr}${gatewayRoutesStr}";

  # List of nets (CIDR) that have at least one address present which satisfies
  # `predicate`.
  networksWithAtLeastOneAddress = encNetworks: predicate:
  let
    hasAtAll = pred: cidrs: lib.any pred cidrs;
  in
    if (hasAtAll predicate (allInterfaceAddresses encNetworks))
    then filter predicate (lib.attrNames encNetworks)
    else [];

  # For each predicate (AF selector): collect nets (CIDR) in the ENC networks
  # whose AF is represented by at least one address (but not necessarily in the
  # same subnet).
  # Example: Assume two IPv4 networks A, B on an interface where A has an
  # address => then both networks are collected. But when none of the networks
  # has an address configured, no net is collected.
  # Returns the union of all nets which match this criterion for at least one AF
  # predicate present in the second argument.
  filterNetworks = encNetworks: predicates:
    lib.concatMap (networksWithAtLeastOneAddress encNetworks) predicates;

  policyRouting =
    { vlan
    , encInterface
    , action ? "start"  # or "stop"
    }:
    let
      filteredNets = filterNetworks encInterface.networks [ isIp4 isIp6 ];
    in
    if action == "start"
    then ''
      ${ipRules vlan encInterface filteredNets "add"}
      ${ipRoutes vlan encInterface filteredNets "add"}
    '' else ''
      ${ipRoutes vlan encInterface filteredNets "del"}
      ${ipRules vlan encInterface filteredNets "del"}
    '';
}
