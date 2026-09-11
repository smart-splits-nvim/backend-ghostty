{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
  };
  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        nlua = pkgs.writeShellScriptBin "nlua" ''
          exec ${pkgs.neovim}/bin/nvim -u NONE -U NONE -N -i NONE \
            -l ${pkgs.lua51Packages.nlua}/bin/nlua "$@"
        '';
        packages =
          (with pkgs; [
            git
            gnumake
            stylua
            selene
            just
            neovim
            lua-language-server
            lua51Packages.busted
          ])
          ++ [ nlua ]
          ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.swift ];
      in
      {
        devShells.default = pkgs.mkShell {
          name = "backend-ghostty";
          inherit packages;
        };
        devShells.ci = pkgs.mkShell {
          name = "ci";
          inherit packages;
        };
      }
    );
}
