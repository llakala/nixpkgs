{
  lib,
  stdenv,
}:
# A special kind of derivation that is only meant to be consumed by the
# nix-shell.
lib.extendMkDerivation {
  constructDrv = stdenv.mkDerivation;

  excludeDrvArgNames = [
    "packages"
    "inputsFrom"
  ];

  extendDrvArgs =
    _finalAttrs:
    {
      name ? "nix-shell",
      # a list of packages to add to the shell environment
      packages ? [ ],
      # propagate all the inputs from the given derivations
      inputsFrom ? [ ],
      ...
    }@attrs:
    let
      mergeInputs =
        name:
        attrs.${name} or [ ]
        ++
          # 1. get all `{build,nativeBuild,...}Inputs` from the elements of `inputsFrom`
          # 2. since that is a list of lists, `flatten` that into a regular list
          # 3. filter out of the result everything that's in `inputsFrom` itself
          # this leaves actual dependencies of the derivations in `inputsFrom`, but never the derivations themselves
          (lib.subtractLists inputsFrom (lib.flatten (lib.catAttrs name inputsFrom)));
    in
    {
      inherit name;

      buildInputs = lib.optionals (inputsFrom == [ ]) (mergeInputs "buildInputs");
      nativeBuildInputs = packages ++ lib.optionals (inputsFrom == [ ]) (mergeInputs "nativeBuildInputs");
      propagatedBuildInputs = lib.optionals (inputsFrom == [ ]) (mergeInputs "propagatedBuildInputs");
      propagatedNativeBuildInputs = lib.optionals (inputsFrom == [ ]) (
        mergeInputs "propagatedNativeBuildInputs"
      );

      shellHook =
        if inputsFrom == [ ] then
          attrs.shellHook or ""
        else
          lib.concatStringsSep "\n" (lib.catAttrs "shellHook" (lib.reverseList inputsFrom ++ [ attrs ]));

      phases = attrs.phases or [ "buildPhase" ];

      buildPhase =
        attrs.buildPhase or ''
          { echo "------------------------------------------------------------";
            echo " WARNING: the existence of this path is not guaranteed.";
            echo " It is an internal implementation detail for pkgs.mkShell.";
            echo "------------------------------------------------------------";
            echo;
            # Record all build inputs as runtime dependencies
            export;
          } >> "$out"
        '';

      preferLocalBuild = attrs.preferLocalBuild or true;
    };
}
