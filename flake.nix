{
  description = "aws-fzf development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        runtimeDeps = with pkgs; [ bash fzf gum jq awscli2 ];
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "aws-fzf";
          version = pkgs.lib.removeSuffix "\n" (builtins.readFile ./version.txt);
          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          installPhase = ''
            mkdir -p $out/share/aws-fzf $out/bin
            cp -r * $out/share/aws-fzf/
            chmod +x $out/share/aws-fzf/aws-fzf
            makeWrapper $out/share/aws-fzf/aws-fzf $out/bin/aws-fzf \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
          '';
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            bash
            fzf
            gum
            bats
            jq
            awscli2
            shellcheck
          ];
        };
      }
    );
}
