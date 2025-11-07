{
  lib,
  stdenv,
  uv,
  makeWrapper,
}:
stdenv.mkDerivation {
  pname = "wled-album-sync";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    mkdir -p $out/bin
    cp wled-album-sync.py $out/bin/wled-album-sync
    wrapProgram $out/bin/wled-album-sync \
      --prefix PATH : ${lib.makeBinPath [uv]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [stdenv.cc.cc.lib]}
  '';
}
