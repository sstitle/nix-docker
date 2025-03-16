{
  description = "Python echo server docker image";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system} = {
      default = pkgs.dockerTools.buildImage {
        name = "echo-server";
        tag = "latest";
        
        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [ pkgs.python3 ];
        };

        config = {
          Cmd = [
            "${pkgs.python3}/bin/python" "-c" ''
              import socket
              import logging
              import sys

              # Configure logging
              logging.basicConfig(
                  level=logging.INFO,
                  format='%(asctime)s - %(levelname)s - %(message)s',
                  stream=sys.stdout
              )

              server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
              server.bind(('0.0.0.0', 8080))
              server.listen(1)
              logging.info("Server started on port 8080")

              while True:
                  conn, addr = server.accept()
                  logging.info(f"New connection from {addr}")
                  data = conn.recv(1024)
                  logging.info(f"Received: {data.decode().strip()}")
                  conn.send(data)
                  logging.info(f"Sent response back to {addr}")
                  conn.close()
                  logging.info(f"Connection closed with {addr}")
            ''
          ];
          ExposedPorts = {
            "8080/tcp" = {};
          };
        };
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
          ${pkgs.docker}/bin/docker run -d -p 8080:8080 echo-server:latest
        '');
      };
      demo = {
        type = "app";
        program = toString (pkgs.writeScript "demo" ''
          #!${pkgs.bash}/bin/bash
          set -e
          echo "Sending test message 'Hello Echo Server!'"
          echo "Hello Echo Server!" | ${pkgs.netcat}/bin/nc localhost 8080
        '');
      };
      destroy = {
        type = "app";
        program = toString (pkgs.writeScript "destroy" ''
          #!${pkgs.bash}/bin/bash
          set -e
          echo "Cleaning up containers..."
          ${pkgs.docker}/bin/docker stop $(${pkgs.docker}/bin/docker ps -q --filter ancestor=echo-server:latest) || true
          ${pkgs.docker}/bin/docker rm $(${pkgs.docker}/bin/docker ps -a -q --filter ancestor=echo-server:latest) || true
          echo "Cleanup complete"
        '');
      };
    };
  };
}
