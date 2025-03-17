{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages = {
        hello = pkgs.hello;
        default = self.packages.${system}.hello;
      };

      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          nodejs
        ];
      };
    });
}
