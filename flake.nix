{
  description = "JavaScript example flake for Zero to Nix";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2405.*.tar.gz";
  };

  outputs = { self, nixpkgs }:
    let
      # Systems supported
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      # Helper to provide system-specific attributes
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
    in
    {
      packages = forAllSystems ({ pkgs }: {
        zero-to-nix-javascript = pkgs.buildNpmPackage {
          name = "zero-to-nix-javascript";

          buildInputs = with pkgs; [
            nodejs_latest
          ];

          src = self;

          npmDepsHash = "sha256-RR0uypDfVTJ/EMOxUnxdLnBbEZasHO+LqLkRAb2mDyg=";

          npmBuild = "npm run build";

          installPhase = ''
            mkdir $out
            cp dist/index.html $out
          '';
        };
        default = self.packages.${pkgs.system}.zero-to-nix-javascript;
      });

      apps = forAllSystems ({ pkgs }: {
        default = {
          type = "app";
          program = toString (pkgs.writeShellScript "open-result" ''
            ${pkgs.xdg-utils}/bin/xdg-open ${self.packages.${pkgs.system}.zero-to-nix-javascript}/index.html
          '');
        };
      });
    };
}
