{
  buildPgrxExtension,
  cargo-pgrx_0_12_0_alpha_1,
  clang_16,
  fetchFromGitHub,
  lib,
  nix-update-script,
  nixosTests,
  openssl,
  pkg-config,
  postgresql,
  replaceVars,
  rustPlatform,
}:

let
  # Upstream only works with clang 16, so we're pinning it here to
  # avoid future incompatibility.
  # See https://docs.vectorchord.ai/developers/development.html#set-up-development-environment, step 2
  clang = clang_16;
  rustPlatform' = rustPlatform // {
    bindgenHook = rustPlatform.bindgenHook.override { inherit clang; };
  };

in
(buildPgrxExtension.override {
  # Upstream only works with a fixed version of cargo-pgrx for each release,
  # so we're pinning it here to avoid future incompatibility.
  # See https://docs.vectorchord.ai/developers/development.html#set-up-development-environment, step 5
  cargo-pgrx = cargo-pgrx_0_12_0_alpha_1;
  rustPlatform = rustPlatform';
})
  (finalAttrs: {
    inherit postgresql;

    pname = "pgvecto-rs";
    version = "0.3.0";

    buildInputs = [ openssl ];
    nativeBuildInputs = [ pkg-config ];

    patches = [
      # Tell the `c` crate to use the flags from the rust bindgen hook
      (replaceVars ./0001-read-clang-flags-from-environment.diff {
        clang = lib.getExe clang;
      })
    ];

    src = fetchFromGitHub {
      owner = "tensorchord";
      repo = "pgvecto.rs";
      tag = "v${finalAttrs.version}";
      hash = "sha256-X7BY2Exv0xQNhsS/GA7GNvj9OeVDqVCd/k3lUkXtfgE=";
    };

    useFetchCargoVendor = true;
    cargoHash = "sha256-8otJ1uqGrCmlxAqvfAL3OjhBI4I6dAu6EoajstO46Sw=";

    # Set appropriate version on vectors.control, otherwise it won't show up on PostgreSQL
    postPatch = ''
      substituteInPlace ./vectors.control --subst-var-by CARGO_VERSION ${finalAttrs.version}
    '';

    # Include upgrade scripts in the final package
    # https://github.com/tensorchord/pgvecto.rs/blob/v0.2.0/scripts/ci_package.sh#L6-L8
    postInstall = ''
      cp sql/upgrade/* $out/share/postgresql/extension/
    '';

    env = {
      # Needed to get openssl-sys to use pkg-config.
      OPENSSL_NO_VENDOR = 1;

      # Bypass rust nightly features not being available on rust stable
      RUSTC_BOOTSTRAP = 1;
    };

    # This crate does not have the "pg_test" feature
    usePgTestCheckFeature = false;

    passthru = {
      updateScript = nix-update-script { };
      tests = nixosTests.postgresql.pgvecto-rs.passthru.override postgresql;
    };

    meta = {
      # Upstream removed support for PostgreSQL 13 on 0.3.0: https://github.com/tensorchord/pgvecto.rs/issues/343
      broken =
        (lib.versionOlder postgresql.version "14")
        ||
          # PostgreSQL 17 support issue upstream: https://github.com/tensorchord/pgvecto.rs/issues/607
          # Check after next package update.
          lib.versionAtLeast postgresql.version "17" && finalAttrs.version == "0.3.0";
      description = "Scalable, Low-latency and Hybrid-enabled Vector Search in Postgres";
      homepage = "https://github.com/tensorchord/pgvecto.rs";
      license = lib.licenses.asl20;
      maintainers = with lib.maintainers; [
        diogotcorreia
        esclear
      ];
    };
  })
