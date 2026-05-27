{ lib }:
let
  inherit (lib)
    attrNames
    concatMap
    elemAt
    fix
    groupBy
    head
    lists
    split
    splitString
    stringLength
    substring
    ;

  inherit (lib.systems) parse;
  inherit (parse)
    mkSystemFromSkeleton
    mkSkeletonFromList
    doubleFromSystem
    ;
  inherit (lib.systems.inspect) predicates;
  inherit (lib.attrsets) matchAttrs;

  all = [
    # our primary systems. at the top of the list for fastest matching
    # inside check-meta
    "x86_64-linux"
    "aarch64-darwin"
    "aarch64-linux"

    # Cygwin
    "i686-cygwin"
    "x86_64-cygwin"

    # FreeBSD
    "i686-freebsd"
    "x86_64-freebsd"
    "aarch64-freebsd"

    # Genode
    "aarch64-genode"
    "i686-genode"
    "x86_64-genode"

    # illumos
    "x86_64-solaris"

    # JS
    "javascript-ghcjs"

    # Linux (excluding the primary two at the top)
    "arc-linux"
    "armv5tel-linux"
    "armv6l-linux"
    "armv7a-linux"
    "armv7l-linux"
    "i686-linux"
    "loongarch64-linux"
    "m68k-linux"
    "sh4-linux"
    "microblaze-linux"
    "microblazeel-linux"
    "mips-linux"
    "mips64-linux"
    "mips64el-linux"
    "mipsel-linux"
    "powerpc-linux"
    "powerpc64-linux"
    "powerpc64le-linux"
    "riscv32-linux"
    "riscv64-linux"
    "s390-linux"
    "s390x-linux"

    # MMIXware
    "mmix-mmixware"

    # NetBSD
    "aarch64-netbsd"
    "armv6l-netbsd"
    "armv7a-netbsd"
    "armv7l-netbsd"
    "i686-netbsd"
    "m68k-netbsd"
    "mipsel-netbsd"
    "powerpc-netbsd"
    "riscv32-netbsd"
    "riscv64-netbsd"
    "x86_64-netbsd"

    # none
    "aarch64_be-none"
    "aarch64-none"
    "arm-none"
    "armv6l-none"
    "avr-none"
    "i686-none"
    "microblaze-none"
    "microblazeel-none"
    "mips-none"
    "mips64-none"
    "msp430-none"
    "or1k-none"
    "m68k-none"
    "powerpc-none"
    "powerpcle-none"
    "riscv32-none"
    "riscv64-none"
    "rx-none"
    "s390-none"
    "s390x-none"
    "vc4-none"
    "x86_64-none"

    # OpenBSD
    "i686-openbsd"
    "x86_64-openbsd"

    # Redox
    "x86_64-redox"

    # WASI
    "wasm64-wasi"
    "wasm32-wasi"

    # Windows
    "aarch64-windows"
    "x86_64-windows"
    "i686-windows"

    # UEFI
    "aarch64-uefi"
    "x86_64-uefi"
  ];

  splitOnDash = split "-";
  firstComponent = groupBy (str: head (splitOnDash str)) all;
  # elemAt x 2 gives us the element after the -, without needing to filter
  secondComponent = groupBy (str: elemAt (splitOnDash str) 2) all;

  systemsWithPrefix =
    prefix: component:
    let
      getPrefix = substring 0 (stringLength prefix);
    in
    concatMap (name: if getPrefix name == prefix then component.${name} else [ ]) (attrNames component);

  uncheckedSystemFromString =
    let
      systemType = {
        _type = "system";
      };
    in
    s: mkSystemFromSkeleton (mkSkeletonFromList (splitString "-" s)) // systemType;
  allParsed = map uncheckedSystemFromString all;
  filterDoubles = f: map doubleFromSystem (lists.filter f allParsed);
in
fix (self: {
  inherit all;

  none = [ ];

  arm = systemsWithPrefix "arm" firstComponent;
  armv7 = systemsWithPrefix "armv7" firstComponent;
  aarch = self.arm ++ self.aarch64;
  aarch64 = firstComponent.aarch64;
  x86 = self.i686 ++ self.x86_64;
  i686 = firstComponent.i686;
  x86_64 = firstComponent.x86_64;
  microblaze = firstComponent.microblaze;
  mips = systemsWithPrefix "mips" firstComponent;
  mmix = firstComponent.mmix;
  power = systemsWithPrefix "powerpc" firstComponent;
  riscv = self.riscv32 ++ self.riscv64;
  riscv32 = firstComponent.riscv32;
  riscv64 = firstComponent.riscv64;
  rx = firstComponent.rx;
  vc4 = firstComponent.vc4;
  or1k = firstComponent.or1k;
  m68k = firstComponent.m68k;
  arc = firstComponent.arc;
  sh4 = firstComponent.sh4;
  s390 = firstComponent.s390 ++ self.s390x;
  s390x = firstComponent.s390x;
  loongarch64 = firstComponent.loongarch64;
  js = firstComponent.javascript;

  cygwin = secondComponent.cygwin;
  darwin = secondComponent.darwin;
  freebsd = secondComponent.freebsd;
  # Should be better, but MinGW is unclear.
  gnu =
    filterDoubles (matchAttrs {
      kernel = parse.kernels.linux;
      abi = parse.abis.gnu;
    })
    ++ filterDoubles (matchAttrs {
      kernel = parse.kernels.linux;
      abi = parse.abis.gnueabi;
    })
    ++ filterDoubles (matchAttrs {
      kernel = parse.kernels.linux;
      abi = parse.abis.gnueabihf;
    })
    ++ filterDoubles (matchAttrs {
      kernel = parse.kernels.linux;
      abi = parse.abis.gnuabin32;
    })
    ++ filterDoubles (matchAttrs {
      kernel = parse.kernels.linux;
      abi = parse.abis.gnuabi64;
    })
    ++ filterDoubles (matchAttrs {
      kernel = parse.kernels.linux;
      abi = parse.abis.gnuabielfv1;
    })
    ++ filterDoubles (matchAttrs {
      kernel = parse.kernels.linux;
      abi = parse.abis.gnuabielfv2;
    });
  illumos = secondComponent.solaris;
  linux = secondComponent.linux;
  netbsd = secondComponent.netbsd;
  openbsd = secondComponent.openbsd;
  unix =
    (self.netbsd ++ self.openbsd ++ self.freebsd)
    ++ self.darwin
    ++ self.linux
    ++ self.illumos
    ++ self.cygwin
    ++ self.redox;
  wasi = firstComponent.wasm32 ++ firstComponent.wasm64;
  redox = secondComponent.redox;
  windows = secondComponent.windows;
  genode = secondComponent.genode;
  uefi = secondComponent.uefi;

  embedded = secondComponent.none;
})
