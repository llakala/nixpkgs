{
  lib,
  stdenv,
  rtpPath,
  vimGenDocHook,
  vimCommandCheckHook,
  neovimRequireCheckHook,
}:

{
  addRtp = drv: lib.warn "`addRtp` is deprecated, does nothing." drv;

  buildVimPlugin =
    {
      name ? "${attrs.pname}-${attrs.version}",
      src,
      unpackPhase ? "",
      configurePhase ? ":",
      buildPhase ? ":",
      preInstall ? "",
      postInstall ? "",
      path ? ".",
      addonInfo ? null,
      meta ? { },
      ...
    }@attrs:
    stdenv.mkDerivation (
      attrs
      // {
        name = lib.warnIf (
          attrs ? vimprefix
        ) "The 'vimprefix' is now hardcoded in toVimPlugin" "vimplugin-${name}";

        __structuredAttrs = true;
        inherit
          unpackPhase
          configurePhase
          buildPhase
          addonInfo
          preInstall
          postInstall
          ;

        # dont move the "doc" folder since vim expects it
        forceShare = [
          "man"
          "info"
        ];

        nativeBuildInputs =
          attrs.nativeBuildInputs or [ ]
          ++ lib.optionals (stdenv.buildPlatform.canExecute stdenv.hostPlatform) [
            vimGenDocHook
          ];

        nativeCheckInputs =
          attrs.nativeCheckInputs or [ ]
          ++ lib.optionals (stdenv.buildPlatform.canExecute stdenv.hostPlatform) [
            vimCommandCheckHook
            # many neovim plugins keep using buildVimPlugin
            neovimRequireCheckHook
          ];

        installPhase = ''
          runHook preInstall

          target=$out/${rtpPath}/${path}
          mkdir -p $out/${rtpPath}
          cp -r . $target

          runHook postInstall
        '';

        meta = {
          platforms = lib.platforms.all;
        }
        // meta;
        passthru = (attrs.passthru or {}) // {
          vimPlugin = true;
        };
      }
    );

}
