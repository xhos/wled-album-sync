{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.wled-album-sync;
in

{
  options.services.wled-album-sync = {
    enable = lib.mkEnableOption "WLED album sync service";

    envFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to environment file containing WLED_URL, SPOTIFY_*, HA_* variables";
      example = "/run/secrets/wled-album-sync.env";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.wled-album-sync = {
      description = "WLED album sync";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.wled-album-sync}";
        EnvironmentFile = cfg.envFile;
        Restart = "on-failure";
        RestartSec = 10;
        DynamicUser = true;
      };
    };
  };
}
