{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

pkgs.mkShell {
  packages = [
    (pkgs.python3.withPackages (ps: [ ps.requests ps.docker ]))
    pkgs.ansible
    pkgs.vagrant
  ];
}
