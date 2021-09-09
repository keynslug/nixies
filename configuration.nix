{ pkgs, ... }: {

  imports = [
    # You should probably generate that with `nixos-generate-config`.
    # Alternatively, take a look at the collection in the `hardware-config` directory.
    ./hardware-configuration.nix
    # Include any needed profiles here
  ];

  boot.cleanTmpDir = true;

  environment.systemPackages = with pkgs; [
    htop
    fish
    jq
    git
  ];

  programs = {
    fish = { enable = true; };
  };

  environment.shells = [ pkgs.fish ];
  environment.interactiveShellInit = ''
    export TERM=xterm-256color
  '';

  networking.hostName = "scw-pixie"; # You probably should edit that

  users.defaultUserShell = pkgs.fish;

}
