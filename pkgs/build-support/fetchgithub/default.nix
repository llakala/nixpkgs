{
  lib,
  repoRevToNameMaybe,
  fetchgit,
  fetchzip,
  config,
}@args:
let
  inherit (lib)
    attrNames
    functionArgs
    makeOverridable
    mapAttrs
    optionalAttrs
    optionalString
    overrideExisting
    revOrTag
    setFunctionArgs
    xor
    ;

  # Here defines fetchFromGitHub arguments that determines useFetchGit,
  # The attribute value is their default values.
  # As fetchFromGitHub prefers fetchzip for hash stability,
  # `defaultFetchZipArgs` attributes should lead to `useFetchGit = false`.
  nonNullableFetchGitArgs = {
    deepClone = false;
    fetchSubmodules = false; # This differs from fetchgit's default
    fetchLFS = false;
    forceFetchGit = false;
    leaveDotGit = null;
    postCheckout = "";
    rootDir = "";
    sparseCheckout = null;
  };
  nullableFetchGitArgs = {
    leaveDotGit = false;
    sparseCheckout = [ ];
  };

  defaultFetchZipArgs = nonNullableFetchGitArgs // nullableFetchGitArgs;

  overrideFetchGitArgs = overrideExisting (removeAttrs nonNullableFetchGitArgs excludedFetchGitNames);

  sourceNameIsSource = config.fetchedSourceNameDefault == "source";

  excludedPassthruNames = [
    "owner"
    "repo"
    "tag"
    "rev"
    "functionName"
    "private"
    "githubBase"
    "varPrefix"
  ];

  # useFetchGitArgsWD to exclude from automatic passing.
  # Other useFetchGitArgsWD will pass down to fetchgit.
  excludedFetchGitNames = [ "forceFetchGit" ];

  excludePassthruFetchGitNames = excludedPassthruNames ++ excludedFetchGitNames;
  excludedPassthruFetchZipNames = excludedPassthruNames ++ attrNames nonNullableFetchGitArgs;

  faUseFetchGit = mapAttrs (_: _: true) nonNullableFetchGitArgs;

  adjustFunctionArgs = f: setFunctionArgs f (faUseFetchGit // functionArgs f);

  decorate = f: makeOverridable (adjustFunctionArgs f);

  # fetchzip may not be overridable when using external tools, for example nix-prefetch
  fetchzip =
    if args.fetchzip ? override then args.fetchzip.override { withUnzip = false; } else args.fetchzip;
in
decorate (
  {
    owner,
    repo,
    tag ? null,
    rev ? null,
    functionName ? "fetchFromGitHub",
    # TODO(@ShamrockLee): Add back after reconstruction with lib.extendMkDerivation
    # name ? repoRevToNameMaybe finalAttrs.repo (lib.revOrTag finalAttrs.revCustom finalAttrs.tag) "github",
    private ? false,
    githubBase ? "github.com",
    varPrefix ? null,
    passthru ? { },
    meta ? { },
    ... # For hash agility and additional fetchgit arguments
  }@args:

  assert (
    xor (tag == null) (rev == null)
    || throw "${functionName} requires one of either `rev` or `tag` to be provided (not both)."
  );

  let
    useFetchGit = lib.any (
      arg:
      defaultFetchZipArgs ? ${arg} # the arg is important for choosing between fetchzip and fetchgit
      && args.${arg} != defaultFetchZipArgs.${arg} # the arg is different from the fetchzip value
      && (!nullableFetchGitArgs ? ${arg} || args.${arg} != null) # the arg is non-nullable or non-null
    ) (lib.attrNames args);

    useFetchGitArgsWDPassing = overrideFetchGitArgs args;

    position = (
      if args.meta.description or null != null then
        builtins.unsafeGetAttrPos "description" args.meta
      else if tag != null then
        builtins.unsafeGetAttrPos "tag" args
      else
        builtins.unsafeGetAttrPos "rev" args
    );
    baseUrl = "https://${githubBase}/${owner}/${repo}";
    passthruAttrs = removeAttrs args (
      (if useFetchGit then excludePassthruFetchGitNames else excludedPassthruFetchZipNames)
    );
    varBase = "NIX${optionalString (varPrefix != null) "_${varPrefix}"}_GITHUB_PRIVATE_";
    # We prefer fetchzip in cases we don't need submodules as the hash
    # is more stable in that case.
    fetcher = if useFetchGit then fetchgit else fetchzip;
    privateAttrs = optionalAttrs private {
      netrcPhase =
        # When using private repos:
        # - Fetching with git works using https://github.com but not with the GitHub API endpoint
        # - Fetching a tarball from a private repo requires to use the GitHub API endpoint
        let
          machineName = if githubBase == "github.com" && !useFetchGit then "api.github.com" else githubBase;
        in
        ''
          if [ -z "''$${varBase}USERNAME" -o -z "''$${varBase}PASSWORD" ]; then
            echo "Error: Private ${functionName} requires the nix building process (nix-daemon in multi user mode) to have the ${varBase}USERNAME and ${varBase}PASSWORD env vars set." >&2
            exit 1
          fi
          cat > netrc <<EOF
          machine ${machineName}
                  login ''$${varBase}USERNAME
                  password ''$${varBase}PASSWORD
          EOF
        '';
      netrcImpureEnvVars = [
        "${varBase}USERNAME"
        "${varBase}PASSWORD"
      ];
    };

    gitRepoUrl = "${baseUrl}.git";

    fetcherArgs =
      finalAttrs:
      passthruAttrs
      // (
        if useFetchGit then
          useFetchGitArgsWDPassing
          // {
            inherit tag rev;
            url = gitRepoUrl;
            inherit passthru;
            derivationArgs = {
              inherit
                githubBase
                owner
                repo
                ;
            };
          }
        else
          {
            # Use the API endpoint for private repos, as the archive URI doesn't
            # support access with GitHub's fine-grained access tokens.
            #
            # Use the archive URI for non-private repos, as the API endpoint has
            # relatively restrictive rate limits for unauthenticated users.
            url =
              if private then
                if githubBase == "github.com" then
                  "https://api.github.com/repos/${finalAttrs.owner}/${finalAttrs.repo}/tarball/${finalAttrs.rev}"
                else
                  "https://${githubBase}/api/v3/repos/${finalAttrs.owner}/${finalAttrs.repo}/tarball/${finalAttrs.rev}"
              else
                "${baseUrl}/archive/${finalAttrs.rev}.tar.gz";
            extension = "tar.gz";
            derivationArgs = {
              inherit
                githubBase
                owner
                repo
                tag
                ;
              rev = fetchgit.getRevWithTag {
                inherit (finalAttrs) tag;
                rev = finalAttrs.revCustom;
              };
              revCustom = rev;
            };
            passthru = {
              inherit gitRepoUrl;
            }
            // passthru;
          }
      )
      // privateAttrs
      // {
        # TODO(@ShamrockLee): Change back to `inherit name;` after reconstruction with lib.extendMkDerivation
        name =
          args.name or (
            if sourceNameIsSource then
              "source"
            else
              repoRevToNameMaybe finalAttrs.repo (revOrTag finalAttrs.revCustom finalAttrs.tag) "github"
          );
        meta =
          meta
          // {
            homepage = meta.homepage or baseUrl;
            identifiers = {
              purlParts =
                if githubBase == "github.com" then
                  {
                    type = "github";
                    # https://github.com/package-url/purl-spec/blob/18fd3e395dda53c00bc8b11fe481666dc7b3807a/types-doc/github-definition.md
                    spec = "${owner}/${repo}@${(revOrTag rev tag)}";
                  }
                else
                  {
                    type = "generic";
                    # https://github.com/package-url/purl-spec/blob/18fd3e395dda53c00bc8b11fe481666dc7b3807a/types-doc/generic-definition.md
                    spec = "${repo}?vcs_url=https://${githubBase}/${owner}/${repo}@${(revOrTag rev tag)}";
                  };
            }
            // meta.identifiers or { };
          }
          // optionalAttrs (position != null) {
            # to indicate where derivation originates, similar to make-derivation.nix's mkDerivation
            position = "${position.file}:${toString position.line}";
          };
      };
  in

  fetcher fetcherArgs
)
