{
  description = "Small web server demo";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        muslpkgs = pkgs.pkgsMusl;

        lighttpd-nossl = muslpkgs.lighttpd.overrideAttrs (prev: {
          configureFlags = [];
          buildInputs = (pkgs.lib.lists.remove muslpkgs.openssl prev.buildInputs);
        });

        port = "3000";
        docroot = "/tmp/webserver";
        variable = "$BRUH";
        placeholder = "PLACEHOLDER";
        file-to-replace = "${docroot}/overview.json";

        httpdconf = pkgs.writeText "lighttpd.conf" ''
          server.modules = (
            "mod_accesslog"
          )
          accesslog.filename = "/dev/fd/2"
          server.document-root = "${docroot}"
          server.port = ${port}
        '';
        statics = pkgs.copyPathToStore ./public/.;
      in
      {
        packages = {
          webserver = pkgs.writeScriptBin "webserver" ''
            #!${muslpkgs.busybox}/bin/sh
            set -eu
            export PATH=${muslpkgs.busybox}/bin/:${lighttpd-nossl}/bin/:$PATH
            echo will use port ${port}...
            mkdir -p ${docroot}
            install -Dm644 ${statics}/* -t ${docroot}
            sed -i "s=${placeholder}=${variable}=g" ${file-to-replace}
            exec lighttpd -D -f ${httpdconf}
          '';
          default = pkgs.dockerTools.buildImage {
            name = "webserver-with-statics";
            tag = "latest"; 
            config = {
              Env = [ "$BRUH=aisughd" ];
              Cmd = [ (pkgs.lib.getExe self.packages.${system}.webserver) ];
            };
          };
        };
      }
    );
}
