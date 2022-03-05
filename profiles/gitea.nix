{config, lib, pkgs, ...}:

with lib;

let
    giteaDomain = "git.keynfawk.es";
    defaultGateway = config.networking.defaultGateway.interface;
in
{
    services.gitea = {
        enable = true;
        enableUnixSocket = true;
        database.type = "postgres";
        database.createDatabase = true;
        domain = giteaDomain;
        rootUrl = "https://${giteaDomain}/";
        disableRegistration = true;
        settings = {
            service = {
                REQUIRE_SIGNIN_VIEW = true;
            };
        };
    };

    services.nginx = let
        giteaSocket = config.services.gitea.settings.server.HTTP_ADDR;
    in {
        enable = true;
        package = pkgs.nginxMainline;
        recommendedTlsSettings = true;
        recommendedProxySettings = true;
        virtualHosts = listToAttrs [
            (nameValuePair giteaDomain {
                forceSSL = true;
                enableACME = true;
                locations."/" = {
                    proxyPass = "http://unix:${giteaSocket}:/";
                };
            })
        ];
    };

    security.acme = {
        # NOTE
        # Do not forget to put correct email address here
        # email = "keynslug@mail";
        acceptTerms = true;
        renewInterval = "monthly";
    };

    networking.firewall.interfaces = listToAttrs [
        (nameValuePair defaultGateway {
            allowedTCPPorts = [ 80 443 ];
        })
    ];
}
