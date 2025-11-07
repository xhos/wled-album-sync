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
    makeWrapper ${lib.getExe uv} $out/bin/wled-album-sync \
      --add-flags "run ${./wled-album-sync.py}" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [stdenv.cc.cc.lib]}
  '';
}
