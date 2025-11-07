{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = f:
      nixpkgs.lib.genAttrs
      ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]
      (system: f nixpkgs.legacyPackages.${system});
  in {
    packages = forAllSystems (pkgs: {
      default = pkgs.callPackage ./package.nix { };
      wled-album-sync = pkgs.callPackage ./package.nix { };

      # inherit env vars
      get-refresh-token = pkgs.writeShellScriptBin "get-refresh-token" ''
        export PATH=${pkgs.lib.makeBinPath [ pkgs.curl pkgs.jq pkgs.coreutils ]}:$PATH
        ${builtins.readFile ./get-refresh-token.sh}
      '';
    });

    nixosModules.default = import ./module.nix;

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          uv
          stdenv.cc.cc.lib
        ];

        env.LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH";
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}