{
  lib,
  stdenv,
  uv,
  makeWrapper,
  curl,
  jq,
}:

stdenv.mkDerivation {
  pname = "wled-album-sync";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    cp wled-album-sync.py $out/bin/wled-album-sync
    chmod +x $out/bin/wled-album-sync
    wrapProgram $out/bin/wled-album-sync \
      --prefix PATH : ${lib.makeBinPath [ uv ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}

    cp get-refresh-token.sh $out/bin/wled-album-sync-get-token
    chmod +x $out/bin/wled-album-sync-get-token
    wrapProgram $out/bin/wled-album-sync-get-token \
      --prefix PATH : ${lib.makeBinPath [ curl jq ]}

    runHook postInstall
  '';

  meta = {
    description = "Sync Spotify/Home Assistant album art colors to WLED";
    license = lib.licenses.mit;
    mainProgram = "wled-album-sync";
    platforms = lib.platforms.linux;
  };
}
