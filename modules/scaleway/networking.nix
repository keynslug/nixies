{config, pkgs, lib, ...}:

with lib;

let

  cfg = config.networking.scaleway;
  scwMetadataServer = "http://169.254.42.42/conf?format=json";

  useDHCP =
    config.networking.useDHCP ||
    any (i: i.useDHCP == true) (attrValues config.networking.interfaces);

in

{

  options = {
    networking.scaleway = {

      configureIPv6 = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Assign an IPv6 address and route to the primary network interface,
          provided by the Scaleway Metadata API.
        '';
      };

      interface = mkOption {
        example = "ens2";
        type = types.str;
        description = ''
          Name of the primary network interface.
        '';
      };

    };
  };

  config = mkIf cfg.configureIPv6 {

    networking.scaleway.interface = mkDefault networking.defaultGateway;

    systemd.services."network-${cfg.interface}-scw-ipv6-setup" = {

      description = "Setup IPv6 address and routing on ${cfg.interface} the Scaleway way";

      after = optional useDHCP "dhcpcd.service";
      before = [ "network-online.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "network-online.target" ];

      unitConfig.ConditionCapability = "CAP_NET_ADMIN";

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      stopIfChanged = false;

      path = [ pkgs.iproute pkgs.jq pkgs.curl ];

      script = ''
        scwMetadata=$(curl --fail --silent --show-error '${scwMetadataServer}')
        status=$?
        if [ $status -ne 0 ]; then
          echo "fetching metadata from '${scwMetadataServer}' failed: $status"
          exit 1
        fi

        iface="${cfg.interface}"
        addr="$(echo "$scwMetadata" | jq -r '.ipv6.address')"
        cidr="$(echo "$scwMetadata" | jq -r '.ipv6.address + "/" + .ipv6.netmask')"
        gw="$(echo "$scwMetadata" | jq -r '.ipv6.gateway')"

        state="/run/nixos/network/addresses-scw/$iface"
        mkdir -p $(dirname "$state")
        echo "$cidr" >> $state
        echo -n "adding address $cidr... "
        if out=$(ip -6 addr add "$cidr" dev "$iface" 2>&1); then
          echo "done"
        elif ! echo "$out" | grep "File exists" >/dev/null 2>&1; then
          echo "'ip -6 addr add "$cidr" dev "$iface"' failed: $out"
          exit 1
        fi

        state="/run/nixos/network/routes-scw/$iface"
        mkdir -p $(dirname "$state")
        echo "$gw" >> $state
        echo -n "routing through default gateway $gw... "
        if out=$(ip -6 route replace default via "$gw" dev "$iface" proto static 2>&1); then
          echo "done"
        elif ! echo "$out" | grep "File exists" >/dev/null 2>&1; then
          echo "'ip -6 route replace default via "$gw" dev "$iface" proto static' failed: $out"
          exit 1
        fi
      '';

      preStop = ''
        iface="${cfg.interface}"
        state="/run/nixos/network/routes-scw/$iface"
        if [ -e "$state" ]; then
          read gw < "$state"
          echo -n "deleting default gateway $gw... "
          if out=$(ip -6 route del default via "$gw" dev "$iface" 2>&1); then
            echo "done"
          else
            echo "'ip -6 route del default via "$gw" dev "$iface"' failed: $out"
          fi
          rm -f "$state"
        fi

        state="/run/nixos/network/addresses-scw/$iface"
        if [ -e "$state" ]; then
          while read cidr; do
            echo -n "deleting address $cidr... "
            if out=$(ip -6 addr del "$cidr" dev "$iface" 2>&1); then
              echo "done"
            else
              echo "'ip -6 addr del "$cidr" dev "$iface"' failed: $out"
            fi
          done < "$state"
          rm -f "$state"
        fi
      '';

    };

  };

}
