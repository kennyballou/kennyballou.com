{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.autogen
    pkgs.awscli
    pkgs.bashInteractive
    pkgs.gnumake
    pkgs.jq
  ];
}
