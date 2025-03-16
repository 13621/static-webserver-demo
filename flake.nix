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
        statics = pkgs.copyPathToStore ./public/.;

        httpdconf = pkgs.writeText "lighttpd.conf" ''
          server.modules = (
            "mod_accesslog"
          )
          accesslog.filename = "/dev/fd/2"
          server.document-root = "${docroot}"
          server.port = ${port}
        '';
        httpdconf-noreplacing = pkgs.writeText "lighttpd.conf" ''
           server.modules = (
            "mod_accesslog"
          )
          accesslog.filename = "/dev/fd/2"
          server.document-root = "${statics}"
          server.port = ${port}
        '';
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
          docker-replacing = pkgs.dockerTools.buildImage {
            name = "webserver-with-statics";
            tag = "latest"; 
            config = {
              Env = [ "BRUH=" ];
              Cmd = [ (pkgs.lib.getExe self.packages.${system}.webserver) ];
            };
          };
          docker-noreplacing = pkgs.dockerTools.buildImage {
            name = "webserver-with-statics";
            tag = "slim";
            config.Cmd = [ (pkgs.lib.getExe lighttpd-nossl) "-D" "-f" httpdconf-noreplacing ];
          };
          docker-veryslim = pkgs.dockerTools.buildImage {
            name = "webserver-with-statics";
            tag = "slimmest";
            config.Cmd = [ "${muslpkgs.busybox}/bin/httpd" "-vv" "-f" "-p" port "-h" statics ];
          };
          default = self.packages.${system}.docker-noreplacing;
        };
      }
    );
}
