{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  asciidoctor,
  buildah,
  buildah-unwrapped,
  cargo,
  libiconv,
  libkrun,
  libkrun-efi,
  libkrunfw,
  makeWrapper,
  rustc,
  sigtool,
}:

let
  libkrun' =
    if stdenv.hostPlatform.isDarwin then
      libkrun.override {
        withBlk = true;
        withNet = true;
        withGpu = false;
        withTimesync = true;
      }
    else
      libkrun;
in
stdenv.mkDerivation rec {
  pname = "krunvm";
  version = "0.2.6";

  src = fetchFromGitHub {
    owner = "libkrun";
    repo = "krunvm";
    rev = "v${version}";
    hash = "sha256-peOaPivQKOwioh5skPNFiA3ptHv9pSsnjpy43cms8O8=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    hash = "sha256-MRcQ0Vnd3PJqE2q981JpXPjwMUKT4t+RcOvzWptK7PQ=";
  };

  nativeBuildInputs = [
    rustPlatform.cargoSetupHook
    cargo
    rustc
    asciidoctor
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ sigtool ];

  buildInputs = [
    libkrun'
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    libiconv
  ];

  makeFlags = [ "PREFIX=${placeholder "out"}" ];

  postPatch = ''
    # do not pollute etc
    substituteInPlace src/utils.rs \
      --replace-fail "etc/containers" "share/krunvm/containers"

    # Fix upstream typo so macOS accepts the library-validation entitlement.
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      substituteInPlace krunvm.entitlements \
        --replace-fail "disable-library-validationr" "disable-library-validation"
    ''}
  '';

  postInstall = ''
    mkdir -p $out/share/krunvm/containers
    install -D -m755 ${buildah-unwrapped.src}/tests/registries.conf $out/share/krunvm/containers/registries.conf
    install -D -m755 ${buildah-unwrapped.src}/tests/policy.json $out/share/krunvm/containers/policy.json
  '';

  # It attaches entitlements with codesign and strip removes those,
  # voiding the entitlements and making it non-operational.
  dontStrip = stdenv.hostPlatform.isDarwin;

  postFixup = ''
    wrapProgram $out/bin/krunvm \
      --prefix PATH : ${lib.makeBinPath [ buildah ]} \
      --prefix DYLD_LIBRARY_PATH : ${lib.makeLibraryPath [ libkrunfw ]} \
      ${lib.optionalString stdenv.hostPlatform.isDarwin "--set STORAGE_DRIVER vfs"}
  '';

  meta = {
    description = "CLI-based utility for creating microVMs from OCI images";
    homepage = "https://github.com/libkrun/krunvm";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      nickcao
      smissingham
    ];
    platforms = lib.unique (libkrun.meta.platforms ++ libkrun-efi.meta.platforms);
    mainProgram = "krunvm";
  };
}
