{
  description = "React app docker image";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system} = {
      default = pkgs.dockerTools.buildImage {
        name = "react-app";
        tag = "latest";
        
        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [ pkgs.bun ];
        };

        config = {
          Cmd = [
            "${pkgs.bun}/bin/bun" "run" "build"
          ];
          ExposedPorts = {
            "5173/tcp" = {};
          };
          WorkingDir = "/app";
        };
        
        runAsRoot = ''
          #!${pkgs.runtimeShell}
          mkdir -p /app
          cp -r ${pkgs.buildEnv {
            name = "app-source";
            paths = [
              (pkgs.runCommand "app-source" {} ''
                mkdir -p $out
                cp -r ${./package.json} $out/package.json
                cp -r ${./.} $out/
              '')
            ];
          }}/* /app/
          
          # Pre-download dependencies using Nix instead of trying to download during build
          cd /app
          cp -r ${pkgs.buildEnv {
            name = "node-modules";
            paths = [
              (pkgs.runCommand "node-modules" {
                buildInputs = [ pkgs.bun ];
              } ''
                mkdir -p $out/node_modules
                cp ${./package.json} ./package.json
                export HOME=$(pwd)
                bun install --no-progress
                cp -r node_modules/* $out/node_modules/
              '')
            ];
          }}/node_modules /app/
        '';
      };
    };
    apps.${system} = {
      load-and-run = {
        type = "app";
        program = toString (pkgs.writeScript "load-and-run" ''
          #!${pkgs.bash}/bin/bash
          set -e
          image_path=$(nix build .#default --print-out-paths --no-link)
          ${pkgs.docker}/bin/docker load < $image_path
          ${pkgs.docker}/bin/docker run -d -p 5173:5173 react-app:latest
        '');
      };
      destroy = {
        type = "app";
        program = toString (pkgs.writeScript "destroy" ''
          #!${pkgs.bash}/bin/bash
          set -e
          echo "Cleaning up containers..."
          ${pkgs.docker}/bin/docker stop $(${pkgs.docker}/bin/docker ps -q --filter ancestor=react-app:latest) || true
          ${pkgs.docker}/bin/docker rm $(${pkgs.docker}/bin/docker ps -a -q --filter ancestor=react-app:latest) || true
          echo "Cleanup complete"
        '');
      };
    };
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        bun
        nodejs
      ];
    };
  };
}
