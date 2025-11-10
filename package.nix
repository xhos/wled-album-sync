{
  lib,
  python3,
}:

python3.pkgs.buildPythonApplication {
  pname = "wled-album-sync";
  version = "0.1.0";
  pyproject = true;

  src = ./.;

  build-system = with python3.pkgs; [
    setuptools
  ];

  dependencies = with python3.pkgs; [
    requests
    pillow
    colorthief
    numpy
    flask
  ];

  meta = {
    mainProgram = "wled-album-sync";
  };
}
