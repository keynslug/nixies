{config, lib, pkgs, ...}:

with lib;

let
  enableIPv6 = config.networking.enableIPv6;
  defaultGateway = config.networking.defaultGateway.interface;
  wgGateway = "wg0";
  vpnCIDR4 = "10.42.42.1/24";
  vpnCIDR6 = "fc42::1/112";
in

{

  networking.nat = {
    enable = true;
    # enableIPv6 = enableIPv6;
    externalInterface = mkDefault defaultGateway;
    internalInterfaces = [ wgGateway ];
  };

  boot.kernel.sysctl = optionalAttrs enableIPv6 {
    "net.ipv6.conf.all.forwarding" = true;
    "net.ipv6.conf.default.forwarding" = false;
    "net.ipv6.conf.${wgGateway}.forwarding" = true;
    "net.ipv6.conf.${defaultGateway}.forwarding" = false;
  };

  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
  };

  networking.wireguard.interfaces = {

    wg0 = let
      ruleIPv4 = ''POSTROUTING -s ${vpnCIDR4} -o ${defaultGateway} -j MASQUERADE'';
      ruleIPv6 = ''POSTROUTING -s ${vpnCIDR6} -o ${defaultGateway} -j MASQUERADE'';
    in {

      ips = [ vpnCIDR4 ] ++ optional enableIPv6 vpnCIDR6;
      # TODO
      # Right now secrets should be provisioned out of bounds.
      privateKeyFile = "/private/wireguard/keynfawk.es.key";
      listenPort = 51820;

      # This allows the wireguard server to route your traffic to the internet and hence be like a VPN.
      postSetup = ''
        ${pkgs.iptables}/bin/iptables -t nat -A ${ruleIPv4}
        ${optionalString enableIPv6 ''
          ${pkgs.iptables}/bin/ip6tables -t nat -A ${ruleIPv6}
        ''}
      '';

      # This undoes the above command
      postShutdown = ''
        ${pkgs.iptables}/bin/iptables -t nat -D ${ruleIPv4}
        ${optionalString enableIPv6 ''
          ${pkgs.iptables}/bin/ip6tables -t nat -D ${ruleIPv6}
        ''}
      '';

      peers = [

        { # keynslug@kenfawks
          allowedIPs = [ "10.42.42.10/32" "fc42::10/128" ];
          publicKey = "FLsbUZ9qvHbfgVOXkJ/CwooTYRvfOYDlx9GNO+iSSAA=";
        }

        { # butterfly-bird@yoga
          allowedIPs = [ "10.42.42.11/32" "fc42::11/128" ];
          publicKey = "Ic4ZbDno41AUQ9fOTgl54VZ6vO5QwYsWka4aFZ1hDXw=";
        }

        { # keynslug@op5
          allowedIPs = [ "10.42.42.12/32" "fc42::12/128" ];
          publicKey = "jOQs8FjQopCg92u9e/6SqoVeV9tSXQKY3Wvjzpt1Z18=";
        }

        { # keynslug@bootkiller
          allowedIPs = [ "10.42.42.13/32" "fc42::13/128" ];
          publicKey = "rGjcK3BcbzvxKCwq4ssztyWq3SpAteEmt8sxnV5oMyo=";
        }

      ];

    };

  };

}
