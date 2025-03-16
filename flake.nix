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

        docker = pkgs.dockerTools.buildImage {
          name = "zero-to-nix-javascript";
          tag = "latest";

          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = [ pkgs.nginx ];
          };

          extraCommands = ''
            mkdir -p var/log/nginx
            mkdir -p var/cache/nginx
          '';

          runAsRoot = ''
            #!${pkgs.stdenv.shell}
            ${pkgs.dockerTools.shadowSetup}
            groupadd --system nginx
            useradd --system --gid nginx nginx
          '';

          config = {
            Cmd = [ "nginx" "-c" (pkgs.writeText "nginx.conf" ''
              user nginx nginx;
              daemon off;
              error_log /dev/stdout info;
              pid /dev/null;
              events {
                worker_connections 1024;
              }
              http {
                access_log /dev/stdout;
                server {
                  listen 80;
                  index index.html;
                  location / {
                    root ${self.packages.${pkgs.system}.zero-to-nix-javascript};
                  }
                }
              }
            '') ];
            ExposedPorts = {
              "80/tcp" = {};
            };
          };
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

        run-container = {
          type = "app";
          program = toString (pkgs.writeShellScript "run-container" ''
            ${pkgs.docker}/bin/docker load < ${self.packages.${pkgs.system}.docker}
            ${pkgs.docker}/bin/docker run -p 8080:80 zero-to-nix-javascript:latest
          '');
        };

        stop-container = {
          type = "app";
          program = toString (pkgs.writeShellScript "stop-container" ''
            ${pkgs.docker}/bin/docker stop $(${pkgs.docker}/bin/docker ps -q --filter ancestor=zero-to-nix-javascript:latest)
          '');
        };
      });
    };
}
