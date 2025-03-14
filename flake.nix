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
        httpdconf = pkgs.writeText "lighttpd.conf" ''
          server.document-root = "${docroot}"
          server.port = ${port}
        '';
        statics = pkgs.copyPathToStore ./public/.;
      in
      {
        packages = {
          webserver = pkgs.writeScriptBin "webserver" ''
            #!${muslpkgs.busybox}/bin/sh
            ${muslpkgs.busybox}/bin/echo will use port ${port}...
            ${muslpkgs.busybox}/bin/mkdir -p ${docroot}
            ${muslpkgs.busybox}/bin/install -Dm644 ${statics}/* -t ${docroot}
            ${muslpkgs.busybox}/bin/sed -i "s/PLACEHOLDER/$BRUH/g" ${docroot}/test.html
            exec ${lighttpd-nossl}/bin/lighttpd -D -f ${httpdconf}
          '';
          default = pkgs.dockerTools.buildImage {
            name = "webserver-with-statics";
            tag = "latest"; 
            config = {
              Env = [ "BRUH=aisughd" ];
              Cmd = [ (pkgs.lib.getExe self.packages.${system}.webserver) ];
            };
          };
        };
      }
    );
}
