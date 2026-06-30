{
  lib,
  buildPackages,
  fixDarwinDylibNames,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  cargo,
  pkg-config,
  glibc,
  openssl,
  libcap_ng,
  libepoxy,
  libdrm,
  pipewire,
  virglrenderer,
  libkrunfw,
  nix-update-script,
  rustc,
  withBlk ? false,
  withNet ? false,
  withGpu ? false,
  withSound ? false,
  withInput ? false,
  withTimesync ? false,
  variant ? null,
}:

assert lib.elem variant [
  null
  "sev"
  "tdx"
];

let
  version = "1.19.0";
  src = fetchFromGitHub {
    owner = "libkrun";
    repo = "libkrun";
    tag = "v${version}";
    hash = "sha256-g4u34sGdgv6mRRry9b5TAXSx+pmVwCNSD3YNtr6qRxo=";
  };
  libkrunfw' = (libkrunfw.override { inherit variant; });
  initBinary = buildPackages.pkgsCross.aarch64-multiplatform.pkgsStatic.stdenv.mkDerivation {
    pname = "libkrun-init";
    inherit version src;

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild
      cd init
      $CC -O2 -static -Wall -o init init.c dhcp.c
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -D init $out/init
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "libkrun" + lib.optionalString (variant != null) "-${variant}";
  inherit version src;

  outputs = [
    "out"
    "dev"
  ];

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) src;
    hash = "sha256-rxdaqEKDDMxFwRuX6kLhqGyFXJTz+Bx4mJJhYL5nPgU=";
  };

  nativeBuildInputs = [
    rustPlatform.cargoSetupHook
    rustPlatform.bindgenHook
    cargo
    pkg-config
    rustc
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ fixDarwinDylibNames ];

  buildInputs =
    lib.optionals stdenv.hostPlatform.isDarwin [
      libepoxy
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      libcap_ng
      libkrunfw'
      glibc
      glibc.static
    ]
    ++ lib.optionals withGpu [
      libepoxy
      libdrm
      virglrenderer
    ]
    ++ lib.optional withSound pipewire
    ++ lib.optional (variant == "sev" || variant == "tdx") openssl;

  makeFlags = [
    "PREFIX=${placeholder "out"}"
  ]
  ++ lib.optional withBlk "BLK=1"
  ++ lib.optional withNet "NET=1"
  ++ lib.optional withGpu "GPU=1"
  ++ lib.optional withSound "SND=1"
  ++ lib.optional withInput "INPUT=1"
  ++ lib.optional withTimesync "TIMESYNC=1"
  ++ lib.optional (variant == "sev") "SEV=1"
  ++ lib.optional (variant == "tdx") "TDX=1";

  postPatch = lib.optionalString stdenv.hostPlatform.isDarwin ''
    substituteInPlace Makefile --replace-fail \
      '$(LIBRARY_RELEASE_$(OS)): $(SYSROOT_TARGET) $(INIT_BINARY_BSD)' \
      '$(LIBRARY_RELEASE_$(OS)):'
    substituteInPlace Makefile --replace-fail \
      'mv target/release/libkrun.dylib target/release/$(KRUN_BASE_$(OS))' \
      'true'
  '';

  postInstall = ''
    mkdir -p $dev/lib/pkgconfig
    if [ -d $out/lib64/pkgconfig ]; then
      mv $out/lib64/pkgconfig $dev/lib/
    else
      mv $out/lib/pkgconfig $dev/lib/
    fi
    mv $out/include $dev/
  '';

  env = {
    OPENSSL_NO_VENDOR = true;
    # Make sure libkrunfw can be found by dlopen() on Linux.
    RUSTFLAGS = lib.optionalString stdenv.hostPlatform.isLinux (
      toString (
        map (flag: "-C link-arg=" + flag) [
          "-Wl,--push-state,--no-as-needed"
          ("-lkrunfw" + lib.optionalString (variant != null) "-${variant}")
          "-Wl,--pop-state"
        ]
      )
    );
  }
  // lib.optionalAttrs stdenv.hostPlatform.isDarwin {
    KRUN_INIT_BINARY_PATH = "${initBinary}/init";
  };

  passthru.updateScript = nix-update-script {
    attrPath = "libkrun";
  };

  meta = {
    description = "Dynamic library providing Virtualization-based process isolation capabilities";
    homepage = "https://github.com/libkrun/libkrun";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      nickcao
      RossComputerGuy
      nrabulinski
    ];
    platforms = libkrunfw'.meta.platforms ++ [ "aarch64-darwin" ];
  };
})
