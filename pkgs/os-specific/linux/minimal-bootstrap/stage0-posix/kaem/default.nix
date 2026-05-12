{
  lib,
  derivationWithMeta,
  writeText,
  kaem,
  kaem-unwrapped,
  mescc-tools,
  mescc-tools-extra,
  version,
  platforms,
}:

# Once mescc-tools-extra is available we can install kaem at /bin/kaem
# to make it findable in environments
derivationWithMeta {
  inherit version kaem-unwrapped;
  pname = "kaem";
  builder = kaem-unwrapped;
  args = [
    "--verbose"
    "--strict"
    "--file"
    (builtins.toFile "kaem-wrapper.kaem" ''
      mkdir -p ''${out}/bin
      cp ''${kaem-unwrapped} ''${out}/bin/kaem
      chmod 555 ''${out}/bin/kaem
    '')
  ];
  PATH = lib.makeBinPath [ mescc-tools-extra ];

  passthru.runCommand =
    let
      builder = "${kaem}/bin/kaem";
      cachedPath = lib.makeBinPath [
        kaem
        mescc-tools
        mescc-tools-extra
      ];
    in
    name: env: buildCommand:
    derivationWithMeta (
      {
        inherit name builder;

        args = [
          "--verbose"
          "--strict"
          "--file"
          ((if env ? useBuiltin then builtins.toFile else writeText) "${name}-builder" buildCommand)
        ];

        PATH =
          if env.nativeBuildInputs or [ ] == [ ] then
            cachedPath
          else
            lib.makeBinPath (
              env.nativeBuildInputs
              ++ [
                kaem
                mescc-tools
                mescc-tools-extra
              ]
            );
      }
      // (removeAttrs env [ "nativeBuildInputs" ])
    );

  meta = {
    description = "Minimal build tool for running scripts on systems that lack any shell";
    homepage = "https://github.com/oriansj/mescc-tools";
    license = lib.licenses.gpl3Plus;
    teams = [ lib.teams.minimal-bootstrap ];
    inherit platforms;
  };
}
