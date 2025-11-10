{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.services.wled-album-sync;
  wled-album-sync = inputs.wled-album-sync.packages.${pkgs.system}.default;
in {
  options.services.wled-album-sync = {
    enable = lib.mkEnableOption "WLED album sync";

    envFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file for secrets";
    };

    wledUrl = lib.mkOption {
      type = lib.types.str;
      example = "http://10.0.0.85";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };

    homeAssistant = {
      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      entity = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };

    spotify.clientId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.wled-album-sync = {
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${lib.getExe wled-album-sync}";
        EnvironmentFile = lib.mkIf (cfg.envFile != null) cfg.envFile;
        Restart = "on-failure";
        DynamicUser = true;
      };

      environment =
        {
          WLED_URL = cfg.wledUrl;
          HTTP_PORT = toString cfg.port;
        }
        // lib.optionalAttrs (cfg.homeAssistant.url != null) {
          HA_URL = cfg.homeAssistant.url;
        }
        // lib.optionalAttrs (cfg.homeAssistant.entity != null) {
          HA_ENTITY = cfg.homeAssistant.entity;
        }
        // lib.optionalAttrs (cfg.spotify.clientId != null) {
          SPOTIFY_CLIENT_ID = cfg.spotify.clientId;
        };
    };
  };
}
