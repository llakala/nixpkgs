#!/usr/bin/env bash
scriptdir="$(dirname "$0")"
cd "$scriptdir"
nix eval --expr '
  let
    lib = import ./../..;
  in
  lib.generators.toPretty {} (import ./generate.nix { inherit lib; })' --impure --raw
