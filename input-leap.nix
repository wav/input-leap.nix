{ pkgs
, stdenv
, fetchFromGitHub

# qt5 or qt6 doesn't effect behaviour
, withQt6 ? true
, withQt5 ? !withQt6

# optional for wayland
, withX11 ? !stdenv.isDarwin

# required for wayland
# if not
# - the cursor will be invisible
# - the remote desktop request will not be fired
# - the process will not terminate well
, withLibei ? !stdenv.isDarwin

# eis support means that mouse movement takes into account physical screen size
, withEisSupport ? !stdenv.isDarwin
, ...
}:

assert withX11 || withLibei || stdenv.isDarwin;

assert withQt6 != withQt5;

assert withQt5 -> !stdenv.isDarwin;

assert withEisSupport -> withLibei && !stdenv.isDarwin;

let
  version = "2.4.0";
  src = fetchFromGitHub {
    owner = "input-leap";
    repo = "input-leap";
    rev = "ecf1fb6645af7b79e6ea984d3c9698ca0ab6f391";
    hash = "sha256-TEv1xR1wUG3wXNATLLIZKOtW05X96wsPNOlE77OQK54=";
    fetchSubmodules = true;
  };

  glob = dir: pattern: with builtins;
    let
        matches = (filter (n: match pattern n != null)) (attrNames (readDir dir));
    in
    map (m: "${dir}/${m}") matches;

  input-leap-shared = {
    pname = "input-leap";
    inherit version src;
    patches = glob ./patches ".*\\.patch";

    dontWrapQtApps = true;

    meta = {
      description = "Open-source KVM software";
      longDescription = ''
        Input Leap is software that mimics the functionality of a KVM switch, which historically
        would allow you to use a single keyboard and mouse to control multiple computers by
        physically turning a dial on the box to switch the machine you're controlling at any
        given moment. Input Leap does this in software, allowing you to tell it which machine
        to control by moving your mouse to the edge of the screen, or by using a keypress
        to switch focus to a different system.
      '';
      homepage = "https://github.com/input-leap/input-leap";
      license = pkgs.lib.licenses.gpl2Plus;
      maintainers = with pkgs.lib.maintainers; [ kovirobi phryneas twey shymega ];
    };
  };

  input-leap-linux =
    let
      libportalWithEis = with pkgs; (libportal).overrideAttrs (old: {
        version = "0.7.2-unstable";
        nativeBuildInputs = old.nativeBuildInputs ++ [ cmake ]
          ++ lib.optionals (withQt5 && !withX11) [ xorg.xcbproto ];
        propagatedBuildInputs = old.propagatedBuildInputs
          ++ lib.optionals withQt5 [ libsForQt5.full ]
          ++ lib.optionals (withQt5 && withX11) [ libsForQt5.qtx11extras ]
          ++ lib.optionals withQt6 [ qt6.full ];
        src = fetchFromGitHub {
          owner = "flatpak";
          repo = "libportal";
          rev = "33f5c9b3d7b774f79cddc778adec6c36ceadecc7";
          sha256 = "sha256-CZLZ3/AOL0QwIAJaYbevQgd3K0tsVsbYOOsbafv/FsE=";
        };
        outputs = [ "out" "dev" ];
        mesonFlags = [
          (lib.mesonEnable "backend-gtk3" false)
          (lib.mesonEnable "backend-gtk4" false)
          (lib.mesonEnable "backend-qt5" withQt5)
          (lib.mesonEnable "backend-qt6" withQt6)
          (lib.mesonBool "vapi" false)
          (lib.mesonBool "introspection" false)
          (lib.mesonBool "docs" false) # requires introspection=true
        ];
      });
    in

    stdenv.mkDerivation (input-leap-shared // rec{
      nativeBuildInputs = with pkgs; [
        pkg-config
        cmake
        wrapGAppsHook
      ]
      ++ lib.optionals withQt5 [ libsForQt5.qttools ]
      ++ lib.optionals withQt6 [ qt6.qttools ]
      ++ lib.optionals (withQt6 && withX11) [ qt6.qt5compat ];

      buildInputs = with pkgs; [
        curl
        avahi-compat
      ]
      ++ lib.optionals withX11 [
        xorg.libX11
        xorg.libXext
        xorg.libXtst
        xorg.libXinerama
        xorg.libXrandr
        xorg.libXdmcp
        xorg.libICE
        xorg.libSM
      ]
      ++ lib.optionals withQt5 [ libsForQt5.qtbase ]
      ++ lib.optionals withQt6 [ qt6.qtbase ]
      ++ lib.optionals withLibei [
        xorg.xorgproto # also provided by X11
        libxkbcommon
        util-linux # gio
        libselinux # gio
        libsepol # libselinux
        pcre # libselinux
        libei
        (if withEisSupport then libportalWithEis else libportal)
      ];

      cmakeFlags = [
        "-DINPUTLEAP_BUILD_LIBEI=${if withLibei then "ON" else "OFF"}"
        "-DINPUTLEAP_BUILD_X11=${if withX11 then "ON" else "OFF"}" # affects compiling mdns in gui project?
        # "-DINPUTLEAP_BUILD_GUI=ON"
        "-DQT_DEFAULT_MAJOR_VERSION=${if withQt6 then "6" else "5"}"
      ];

      postFixup = ''
        substituteInPlace $out/share/applications/io.github.input_leap.InputLeap.desktop \
          --replace "Exec=input-leap" "Exec=$out/bin/input-leap"
      '';

      preFixup = ''
        qtWrapperArgs+=(
          "''${gappsWrapperArgs[@]}"
            --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.openssl ]}"
        )
      '';

      meta.platforms = pkgs.lib.platforms.linux;

    });

  input-leap-macos =
    stdenv.mkDerivation (input-leap-shared // rec {

      # build time (compiler, ...)
      nativeBuildInputs = with pkgs; [
        # fixes 'cctools-binutils-darwin-16.0.6-973.0.1/bin/strip: error: unsupported load command (cmd=0x8000001f)'
        darwin.cctools
        avahi
        pkg-config
        cmake
        openssl
        qt6.qttools
        qt6.qt5compat
        curl.dev
        # ncurses for tput
        ncurses
      ];

      # runtime
      buildInputs = with pkgs; [
        qt6.qtbase
        darwin.apple_sdk.frameworks.ScreenSaver
        darwin.apple_sdk.frameworks.Cocoa
      ];

      # main CMakeLists.txt
      cmakeFlags = [
        "-DINPUTLEAP_REVISION=${builtins.substring 0 8 src.rev}"
        "-DOPENSSL_LIBS=ssl"
        "-DOPENSSL_LIBS=crypto"
        "-DCMAKE_OSX_ARCHITECTURES=arm64"
      ];

      # nested CMakeLists.txt
      # /usr/bin is on PATH because we need 'hdiutil'
      patchPhase = ''
        substituteInPlace ./src/{client,server,test/unittests}/CMakeLists.txt \
          --replace ' ''${OPENSSL_LIBS}' ' ssl crypto'
        substituteInPlace ./dist/macos/bundle/build_dist.sh.in \
          --replace 'which -s port' 'false' \
          --replace 'which -s brew' 'false' \
          --replace '"$DEPLOYQT"' 'PATH=$PATH:/usr/bin ${pkgs.qt6.qtbase}/bin/macdeployqt' \
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

    });

in
if stdenv.isDarwin then input-leap-macos
else input-leap-linux
