{ ... }: {

  imports = [
    ../modules/scaleway/networking.nix
  ];

  networking = {
    enableIPv6 = true;
    firewall.allowPing = true;
    scaleway = { configureIPv6 = true; interface = "ens2"; };
  };

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkQtNk75rgGGwWElghb3S3C3E4DaKNUhX5DNMb/219c keynslug@kenfawks"
  ];

}
