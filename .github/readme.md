# wled-album-sync

this is a simple standalone script that turns your wled lights into a visualizer that matches the album cover of the currently playing song. only spotify and home assistant media players are supported at the moment.

## setup

required env: `WLED_URL`

optional: `HTTP_PORT` (default: 8080)

at least one of `SPOTIFY_*` or `HA_*` is needed depending on which service you want to use

see [.env.example](../.env.example) for reference

### spotify

create an app at https://developer.spotify.com/dashboard and set the redirect uri to exactly `http://127.0.0.1:8888/callback`

note client id and secret

to get the refresh token you need these env vars:

- `SPOTIFY_CLIENT_ID`
- `SPOTIFY_CLIENT_SECRET`
- `SPOTIFY_REDIRECT_URI=http://127.0.0.1:8888/callback`

to get `SPOTIFY_REFRESH_TOKEN` run [get-refresh-token.sh](../get-refresh-token.sh). running the script will open a browser window you to auth into your spotify account, after that you will be redirected to a page that won't load, all you need is to copy the full url of it and paste it back into the terminal.

if you have nix installed you can run:

```bash
nix run github:xhos/wled-album-sync#get-refresh-token
```

## home assistant

this thing should work with any media player supported by home assistant that provides album covers:

![ha-player](ha-player.png)

`HA_TOKEN` is a long-lived access token from https://my.home-assistant.io/redirect/profile_security
`HA_URL` is the base url of your home assistant instance
`HA_ENTITY` is the entity id of your media player. get it at https://my.home-assistant.io/redirect/entities. make sure you enable the `Entity ID` column in the table on the top right.

## usage

### direct

```bash
uv run wled-album-sync.py
```

### http control

the app exposes an http server (default port 8080, configurable via `HTTP_PORT` env var) to toggle syncing on/off:

```bash
# toggle sync on/off
curl -X POST http://localhost:8080/toggle

# check status
curl http://localhost:8080/status
```

### nixos module

```nix
{
  inputs.wled-album-sync.url = "github:xhos/wled-album-sync";

  outputs = { nixpkgs, wled-album-sync, ... }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      modules = [
        wled-album-sync.nixosModules.default
        {
          services.wled-album-sync = {
            enable = true;
            wledUrl = "http://10.0.0.85";
            port = 8080;

            homeAssistant = {
              url = "http://10.0.0.10:8123";
              entity = "media_player.yandex_station";
            };

            spotify.clientId = "your_client_id";

            # secrets in envFile
            envFile = /run/secrets/wled-album-sync.env;
          };
        }
      ];
    };
  };
}
```

the `envFile` should contain sensitive variables:

```bash
SPOTIFY_CLIENT_SECRET=your_secret
SPOTIFY_REFRESH_TOKEN=your_token
HA_TOKEN=your_ha_token
```

## contributions

feel free to open issues or PRs if you have ideas for improvements or find bugs
