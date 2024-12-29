{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "filen-desktop";
  version = "3.0.41";
  makeCacheWritable = true;

  src = fetchFromGitHub {
    owner = "FilenCloudDienste";
    repo = "filen-desktop";
    rev = "v${version}";
    sha256 = "sha256-HpyASSpjRgBTkV7L5bfi65rO+MnrSP7VdeuL/VXBlSo=";
  };

  npmDepsHash = "sha256-TmKNZpZBD41OFwD9whCWGztPno91ltDZ/+5OX9AJc5Y=";

  meta = with lib; {
    homepage = "https://filen.io/products/desktop";
    downloadPage = "https://github.com/FilenCloudDienste/filen-desktop/releases/";
    description = "Filen Desktop Client for Linux";
    longDescription = ''
      Encrypted Cloud Storage built for your Desktop.
      Sync your data, mount network drives, collaborate with others and access files natively — powered by robust encryption and seamless integration.
    '';
    mainProgram = "filen-desktop";
    platforms = platforms.linux;
    license = lib.licenses.agpl3Only;
    maintainers = with maintainers; [ smissingham ];
  };
}
