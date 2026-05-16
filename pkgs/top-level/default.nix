/*
  This function composes the Nix Packages collection. It:

    1. Elaborates `localSystem` and `crossSystem` with defaults as needed.

    2. Applies the final stage to the given `config` if it is a function

    3. Defaults to no non-standard config and no cross-compilation target

    4. Uses the above to infer the default standard environment's (stdenv's)
       stages if no stdenv's are provided

    5. Folds the stages to yield the final fully booted package set for the
       chosen stdenv

  Use `impure.nix` to also infer the `system` based on the one on which
  evaluation is taking place, and the configuration from environment variables
  or dot-files.
*/

let
  # We hoist this above the closure so that the same thunk is shared
  # between multiple imports of Nixpkgs. This ensures that commands
  # like `nix eval nixpkgs#legacyPackages.x86_64-darwin.pkgsStatic.hello`
  # print only one warning, which would otherwise be spammy in common
  # scenarios that instantiate many copies of Nixpkgs.
  #
  # Unfortunately, flakes’ handling of transitive dependencies mean
  # that it’s still likely users will see multiple warnings, but
  # there’s nothing we can do about that within the constraints of the
  # Nix language.
  x86_64DarwinDeprecationWarning =
    pristineLib.warn
      "Nixpkgs 26.05 will be the last release to support x86_64-darwin; see https://nixos.org/manual/nixpkgs/unstable/release-notes#x86_64-darwin-26.05"
      (x: x);

  pristineLib = import ../../lib;
in

{
  # The system packages will be built on. See the manual for the
  # subtle division of labor between these two `*System`s and the three
  # `*Platform`s.
  localSystem,

  # The system packages will ultimately be run on.
  crossSystem ? null,

  # Allow a configuration attribute set to be passed in as an argument.
  config ? { },

  # Temporary hack to let Nixpkgs forbid internal use of `lib.fileset`
  # until <https://github.com/NixOS/nix/issues/11503> is fixed.
  __allowFileset ? true,

  # List of overlays layers used to extend Nixpkgs.
  overlays ? [ ],

  # List of overlays to apply to target packages only.
  crossOverlays ? [ ],

  # A function booting the final package set for a specific standard
  # environment. See below for the arguments given to that function, the type of
  # list it returns.
  stdenvStages ? import ../stdenv,

  # Ignore unexpected args.
  ...
}@args:

let # Rename the function arguments
  config0 = config;
  crossSystem0 = crossSystem;

in
let
  lib =
    if __allowFileset then
      pristineLib
    else
      pristineLib.extend (
        _: _: {
          fileset = abort ''

            The use of `lib.fileset` is currently forbidden in Nixpkgs due to the
            upstream Nix bug <https://github.com/NixOS/nix/issues/11503>. This
            causes difficult‐to‐debug errors when combined with chroot stores,
            such as in the NixOS installer.

            For packages that require source to be vendored inside Nixpkgs,
            please use a subdirectory of the package instead.
          '';
        }
      );

  inherit (lib) throwIfNot;

  checked =
    (throwIfNot (lib.isList overlays) "The overlays argument to nixpkgs must be a list.")
      (throwIfNot (lib.all lib.isFunction overlays) "All overlays passed to nixpkgs must be functions.")
      (throwIfNot (lib.isList crossOverlays) "The crossOverlays argument to nixpkgs must be a list.")
      (throwIfNot (lib.all lib.isFunction crossOverlays) "All crossOverlays passed to nixpkgs must be functions.")
      (
        if
          (
            ((localSystem.isDarwin && localSystem.isx86) || (crossSystem.isDarwin && crossSystem.isx86))
            && config.allowDeprecatedx86_64Darwin == false
          )
        then
          x86_64DarwinDeprecationWarning
        else
          x: x
      );

  localSystem = {
    _withoutFunctions = {
      aesSupport = false;
      androidNdkVersion = null;
      androidSdkVersion = null;
      avx2Support = false;
      avx512Support = false;
      avxSupport = false;
      config = "x86_64-unknown-linux-gnu";
      darwinArch = "x86_64";
      darwinMinVersion = "14.0";
      darwinMinVersionVariable = null;
      darwinPlatform = null;
      darwinSdkVersion = "14.4";
      efiArch = "x64";
      extensions = {
        executable = "";
        library = ".so";
        sharedLibrary = ".so";
        staticLibrary = ".a";
      };
      fma4Support = false;
      fmaSupport = false;
      gcc = { };
      go = {
        GOARCH = "amd64";
        GOARM = "";
        GOOS = "linux";
      };
      hasSharedLibraries = true;
      is32bit = false;
      is64bit = true;
      isAarch = false;
      isAarch32 = false;
      isAarch64 = false;
      isAbiElfv1 = false;
      isAbiElfv2 = false;
      isAlpha = false;
      isAndroid = false;
      isArc = false;
      isArmv7 = false;
      isAvr = false;
      isBSD = false;
      isBigEndian = false;
      isCygwin = false;
      isDarwin = false;
      isEabi = false;
      isEfi = true;
      isElf = true;
      isFreeBSD = false;
      isGenode = false;
      isGhcjs = false;
      isGnu = true;
      isILP32 = false;
      isJavaScript = false;
      isLinux = true;
      isLittleEndian = true;
      isLoongArch64 = false;
      isM68k = false;
      isMacOS = false;
      isMacho = false;
      isMicroBlaze = false;
      isMinGW = false;
      isMips = false;
      isMips32 = false;
      isMips64 = false;
      isMips64n32 = false;
      isMips64n64 = false;
      isMmix = false;
      isMsp430 = false;
      isMsvc = false;
      isMusl = false;
      isNetBSD = false;
      isNone = false;
      isOpenBSD = false;
      isOr1k = false;
      isPE = false;
      isPower = false;
      isPower64 = false;
      isRedox = false;
      isRiscV = false;
      isRiscV32 = false;
      isRiscV64 = false;
      isRx = false;
      isS390 = false;
      isS390x = false;
      isSh4 = false;
      isSparc = false;
      isSparc64 = false;
      isStatic = false;
      isSunOS = false;
      isUClibc = false;
      isUefi = false;
      isUnix = true;
      isVc4 = false;
      isWasi = false;
      isWasm = false;
      isWindows = false;
      isi686 = false;
      isiOS = false;
      isx86 = true;
      isx86_32 = false;
      isx86_64 = true;
      lasxSupport = false;
      libDir = "lib64";
      libc = "glibc";
      linker = "bfd";
      linux-kernel = {
        autoModules = true;
        baseConfig = "defconfig";
        name = "pc";
        target = "bzImage";
      };
      linuxArch = "x86_64";
      lsxSupport = false;
      nim = {
        cpu = "amd64";
        os = "Linux";
      };
      node = {
        arch = "x64";
        platform = "linux";
      };
      parsed = {
        _type = "system";
        abi = {
          assertions = [
            {
              assertion = <function>;
              message = ''
                The "gnu" ABI is ambiguous on 32-bit ARM. Use "gnueabi" or "gnueabihf" instead.
              '';
            }
            {
              assertion = <function>;
              message = ''
                The "gnu" ABI is ambiguous on big-endian 64-bit PowerPC. Use "gnuabielfv2" or "gnuabielfv1" instead.
              '';
            }
          ];
          name = "gnu";
        };
        cpu = {
          arch = "x86-64";
          bits = 64;
          family = "x86";
          name = "x86_64";
          significantByte = {
            name = "littleEndian";
          };
        };
        kernel = {
          execFormat = {
            name = "elf";
          };
          families = { };
          name = "linux";
        };
        vendor = {
          name = "unknown";
        };
      };
      qemuArch = "x86_64";
      rust = {
        cargoEnvVarTarget = "X86_64_UNKNOWN_LINUX_GNU";
        cargoShortTarget = "x86_64-unknown-linux-gnu";
        isNoStdTarget = false;
        platform = {
          arch = "x86_64";
          os = "linux";
          target-family = [
            "unix"
          ];
          vendor = "unknown";
        };
        rustcTarget = "x86_64-unknown-linux-gnu";
        rustcTargetSpec = "x86_64-unknown-linux-gnu";
      };
      rustc = { };
      sse3Support = false;
      sse4_1Support = false;
      sse4_2Support = false;
      sse4_aSupport = false;
      ssse3Support = false;
      system = "x86_64-linux";
      ubootArch = "x86_64";
      uname = {
        processor = "x86_64";
        release = null;
        system = "Linux";
      };
      useAndroidPrebuilt = false;
      useLLVM = false;
      useiOSPrebuilt = false;
    };
    aesSupport = false;
    androidNdkVersion = null;
    androidSdkVersion = null;
    avx2Support = false;
    avx512Support = false;
    avxSupport = false;
    canExecute =
      platform:
      localSystem.isAndroid == platform.isAndroid
      && lib.systems.parse.isCompatible localSystem.parsed.cpu platform.parsed.cpu
      && localSystem.parsed.kernel == platform.parsed.kernel
      && (
        # Only perform this check when cpus have the same type;
        # assume compatible cpu have all the instructions included
        localSystem.parsed.cpu == platform.parsed.cpu
        ->
          # if platform has gcc.arch, final must also have and can execute the gcc.arch of platform
          (
            platform ? gcc.arch -> localSystem ? gcc.arch && lib.systems.architectures.canExecute localSystem.gcc.arch platform.gcc.arch
          )
      );
    config = "x86_64-unknown-linux-gnu";
    darwinArch = "x86_64";
    darwinMinVersion = "14.0";
    darwinMinVersionVariable = null;
    darwinPlatform = null;
    darwinSdkVersion = "14.4";
    efiArch = "x64";
    extensions = {
      executable = "";
      library = ".so";
      sharedLibrary = ".so";
      staticLibrary = ".a";
    };
    fma4Support = false;
    fmaSupport = false;
    gcc = { };
    go = {
      GOARCH = "amd64";
      GOARM = "";
      GOOS = "linux";
    };
    hasSharedLibraries = true;
    is32bit = false;
    is64bit = true;
    isAarch = false;
    isAarch32 = false;
    isAarch64 = false;
    isAbiElfv1 = false;
    isAbiElfv2 = false;
    isAlpha = false;
    isAndroid = false;
    isArc = false;
    isArmv7 = false;
    isAvr = false;
    isBSD = false;
    isBigEndian = false;
    isCygwin = false;
    isDarwin = false;
    isEabi = false;
    isEfi = true;
    isElf = true;
    isFreeBSD = false;
    isGenode = false;
    isGhcjs = false;
    isGnu = true;
    isILP32 = false;
    isJavaScript = false;
    isLinux = true;
    isLittleEndian = true;
    isLoongArch64 = false;
    isM68k = false;
    isMacOS = false;
    isMacho = false;
    isMicroBlaze = false;
    isMinGW = false;
    isMips = false;
    isMips32 = false;
    isMips64 = false;
    isMips64n32 = false;
    isMips64n64 = false;
    isMmix = false;
    isMsp430 = false;
    isMsvc = false;
    isMusl = false;
    isNetBSD = false;
    isNone = false;
    isOpenBSD = false;
    isOr1k = false;
    isPE = false;
    isPower = false;
    isPower64 = false;
    isRedox = false;
    isRiscV = false;
    isRiscV32 = false;
    isRiscV64 = false;
    isRx = false;
    isS390 = false;
    isS390x = false;
    isSh4 = false;
    isSparc = false;
    isSparc64 = false;
    isStatic = false;
    isSunOS = false;
    isUClibc = false;
    isUefi = false;
    isUnix = true;
    isVc4 = false;
    isWasi = false;
    isWasm = false;
    isWindows = false;
    isi686 = false;
    isiOS = false;
    isx86 = true;
    isx86_32 = false;
    isx86_64 = true;
    lasxSupport = false;
    libDir = "lib64";
    libc = "glibc";
    linker = "bfd";
    linux-kernel = {
      autoModules = true;
      baseConfig = "defconfig";
      name = "pc";
      target = "bzImage";
    };
    linuxArch = "x86_64";
    lsxSupport = false;
    nim = {
      cpu = "amd64";
      os = "Linux";
    };
    node = {
      arch = "x64";
      platform = "linux";
    };
    parsed = {
      _type = "system";
      abi = {
        assertions = [
          {
            assertion = null;
            message = ''
              The "gnu" ABI is ambiguous on 32-bit ARM. Use "gnueabi" or "gnueabihf" instead.
            '';
          }
          {
            assertion = null;
            message = ''
              The "gnu" ABI is ambiguous on big-endian 64-bit PowerPC. Use "gnuabielfv2" or "gnuabielfv1" instead.
            '';
          }
        ];
        name = "gnu";
      };
      cpu = {
        arch = "x86-64";
        bits = 64;
        family = "x86";
        name = "x86_64";
        significantByte = {
          name = "littleEndian";
        };
      };
      kernel = {
        execFormat = {
          name = "elf";
        };
        families = { };
        name = "linux";
      };
      vendor = {
        name = "unknown";
      };
    };
    qemuArch = "x86_64";
    rust = {
      cargoEnvVarTarget = "X86_64_UNKNOWN_LINUX_GNU";
      cargoShortTarget = "x86_64-unknown-linux-gnu";
      isNoStdTarget = false;
      platform = {
        arch = "x86_64";
        os = "linux";
        target-family = [
          "unix"
        ];
        vendor = "unknown";
      };
      rustcTarget = "x86_64-unknown-linux-gnu";
      rustcTargetSpec = "x86_64-unknown-linux-gnu";
    };
    rustc = { };
    sse3Support = false;
    sse4_1Support = false;
    sse4_2Support = false;
    sse4_aSupport = false;
    ssse3Support = false;
    system = "x86_64-linux";
    ubootArch = "x86_64";
    uname = {
      processor = "x86_64";
      release = null;
      system = "Linux";
    };
    useAndroidPrebuilt = false;
    useLLVM = false;
    useiOSPrebuilt = false;
  };

  # Condition preserves sharing which in turn affects equality.
  #
  # See `lib.systems.equals` documentation for more details.
  #
  # Note that it is generally not possible to compare systems as given in
  # parameters, e.g. if systems are initialized as
  #
  #   localSystem = { system = "x86_64-linux"; };
  #   crossSystem = { config = "x86_64-unknown-linux-gnu"; };
  #
  # Both systems are semantically equivalent as the same vendor and ABI are
  # inferred from the system double in `localSystem`.
  crossSystem =
    let
      system = lib.systems.elaborate crossSystem0;
    in
    if crossSystem0 == null || lib.systems.equals system localSystem then localSystem else system;

  # Allow both:
  # { /* the config */ } and
  # { pkgs, ... } : { /* the config */ }
  config1 = if lib.isFunction config0 then config0 { inherit lib pkgs; } else config0;

  configEval = lib.evalModules {
    modules = [
      ./config.nix
      (
        { options, ... }:
        {
          _file = "nixpkgs.config";
          config = config1;
        }
      )
    ];
    class = "nixpkgsConfig";
  };

  # take all the rest as-is
  config =
    let
      failedAssertionsString = lib.concatMapStringsSep "\n" (x: "- ${x.message}") (
        lib.filter (x: !x.assertion) configEval.config.assertions
      );
    in
    if failedAssertionsString != "" then
      throw "Failed assertions:\n${failedAssertionsString}"
    else
      lib.showWarnings configEval.config.warnings configEval.config;

  # A few packages make a new package set to draw their dependencies from.
  # (Currently to get a cross tool chain, or forced-i686 package.) Rather than
  # give `all-packages.nix` all the arguments to this function, even ones that
  # don't concern it, we give it this function to "re-call" nixpkgs, inheriting
  # whatever arguments it doesn't explicitly provide. This way,
  # `all-packages.nix` doesn't know more than it needs too.
  #
  # It's OK that `args` doesn't include default arguments from this file:
  # they'll be deterministically inferred. In fact we must *not* include them,
  # because it's important that if some parameter which affects the default is
  # substituted with a different argument, the default is re-inferred.
  #
  # To put this in concrete terms, this function is basically just used today to
  # use package for a different platform for the current platform (namely cross
  # compiling toolchains and 32-bit packages on x86_64). In both those cases we
  # want the provided non-native `localSystem` argument to affect the stdenv
  # chosen.
  #
  # NB!!! This thing gets its `config` argument from `args`, i.e. it's actually
  # `config0`. It is important to keep it to `config0` format (as opposed to the
  # result of `evalModules`, i.e. the `config` variable above) throughout all
  # nixpkgs evaluations since the above function `config0 -> config` implemented
  # via `evalModules` is not idempotent. In other words, if you add `config` to
  # `newArgs`, expect strange very hard to debug errors! (Yes, I'm speaking from
  # experience here.)
  nixpkgsFun = newArgs: import ./. (args // newArgs);

  # Partially apply some arguments for building bootstrapping stage pkgs
  # sets. Only apply arguments which no stdenv would want to override.
  allPackages =
    newArgs:
    import ./stage.nix (
      {
        inherit lib nixpkgsFun;
      }
      // newArgs
    );

  boot = import ../stdenv/booter.nix { inherit lib allPackages; };

  stages = stdenvStages {
    inherit
      lib
      localSystem
      crossSystem
      config
      overlays
      crossOverlays
      ;
  };

  pkgs = boot stages;

in
checked pkgs
