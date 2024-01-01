{ pkgs, stdenv, fetchFromGitHub, ... }:

let
  inherit (stdenv) isDarwin mkDerivation;

  version = "2.4.0";
  src = fetchFromGitHub {
    owner = "input-leap";
    repo = "input-leap";
    rev = "ecf1fb6645af7b79e6ea984d3c9698ca0ab6f391";
    hash = "sha256-TEv1xR1wUG3wXNATLLIZKOtW05X96wsPNOlE77OQK54=";
    fetchSubmodules = true;
  };

  attrs-linux = {
    inherit version src;
    postFixup = ''
      substituteInPlace $out/share/applications/io.github.input_leap.InputLeap.desktop \
        --replace "Exec=input-leap" "Exec=$out/bin/input-leap"
    '';
  };

  attrs-macos =
    let
      inherit (pkgs.darwin.apple_sdk.frameworks) ScreenSaver Cocoa;

      # fixes 'cctools-binutils-darwin-16.0.6-973.0.1/bin/strip: error: unsupported load command (cmd=0x8000001f)'
      inherit (pkgs.darwin) cctools;

      inherit (pkgs.qt6) qttools qt5compat qtbase;
    in
    {
      inherit version src;

      dontWrapQtApps = true;

      # build time (compiler, ...)
      nativeBuildInputs = with pkgs; [
        cctools
        avahi
        pkg-config
        cmake
        openssl
        qttools
        qt5compat
        curl.dev
        # ncurses for tput
        ncurses
      ];

      # runtime
      buildInputs = with pkgs; [
        qtbase
        ScreenSaver
        Cocoa
      ];

      # main CMakeLists.txt
      cmakeFlags = [
        "-DINPUTLEAP_REVISION=${builtins.substring 0 8 src.rev}"
        "-DOPENSSL_LIBS=ssl"
        "-DOPENSSL_LIBS=crypto"
        "-DCMAKE_OSX_ARCHITECTURES=arm64"
      ];

      # nested CMakeLists.txt
      patchPhase = ''
        substituteInPlace ./src/{client,server,test/unittests}/CMakeLists.txt \
          --replace ' ''${OPENSSL_LIBS}' ' ssl crypto'
        substituteInPlace ./dist/macos/bundle/build_dist.sh.in \
          --replace 'which -s port' 'false' \
          --replace 'which -s brew' 'false' \
          --replace '"$DEPLOYQT"' 'PATH=$PATH:/usr/bin ${qtbase}/bin/macdeployqt' \
          --replace '-dmg' '-dmg -verbose=2'
      '';

      installPhase = ''
        # ''${pkgs.darwin.sigtool}/bin/codesign # missing '--deep' flag
        /usr/bin/codesign --force --deep --sign - bundle/InputLeap.app
        mkdir -p $out/Applications
        mv bundle/InputLeap.app $out/Applications/InputLeap.app
      '';

      postFixup = "";

      meta.platforms = [ "aarch64-darwin" ];

    };

in
pkgs.input-leap.overrideAttrs (_:
if isDarwin then attrs-macos else attrs-linux)
