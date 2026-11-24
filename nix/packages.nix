_: {
  perSystem = {
    self',
    pkgs,
    system,
    ...
  }: let
    inherit (pkgs) lib;
    version = "4.4";
    cudaSupport = false;
    # stdenv = pkgs.clangStdenv;
    stdenv = pkgs.stdenv;

    x11deps = with pkgs; [
      libX11
      libXext
      libXt
      libXi
      libXxf86vm
      libXrender
      libSM
      libICE
      libdrm
      xorgproto
    ];
  in {
    packages = {
      libs = stdenv.mkDerivation (finalAttrs: {
        pname = "blender-deps";
        inherit version;
        src = pkgs.fetchgit {
          inherit ((builtins.fromJSON (builtins.readFile ../libs.json)).${system}) url hash rev;
          fetchLFS = true;
        };

        interpreter =
          if stdenv.hostPlatform.isAarch64
          then "${pkgs.glibc}/lib/ld-linux-aarch64.so.1"
          else "${pkgs.glibc}/lib64/ld-linux-x86-64.so.2";

        installPhase = ''
          mkdir --parents $out
          cp --archive . $out/
          chmod --recursive u+w $out

          rpath="$(find $out -maxdepth 3 -type d -name lib | paste -sd:):${pkgs.glibc}/lib:${stdenv.cc.cc.lib}/lib"
          export rpath
          find $out -type f -print0 | xargs -0 -n1 sh -c '
            f="$1"
            if patchelf --print-interpreter "$f" >/dev/null 2>&1; then
              patchelf --set-interpreter ${finalAttrs.interpreter} "$f"
            fi
            if patchelf --print-rpath "$f" >/dev/null 2>&1; then
              patchelf --set-rpath "$rpath" "$f"
            fi
          ' _
        '';
      });
      default = stdenv.mkDerivation (finalAttrs: {
        pname = "goo-engine";
        inherit version;

        src = pkgs.fetchgit {
          url = "https://github.com/mcahyadit/goo-engine.git";
          rev = "d3dd2290a8f7322a07e4d4c37fd25a49ab4692ca";
          hash = "sha256-VSJTj6k6dtyqSW1OOnJzD8PBzfer20yW5EhFSEAgvt4=";
          fetchLFS = true;
        };

        nativeBuildInputs =
          (with pkgs; [
            cmake
            ninja

            llvmPackages.llvm.dev

            pkg-config
            wayland-scanner
          ])
          ++ lib.optionals cudaSupport (with pkgs; [
            addDriverRunpath
            cudaPackages.cuda_nvcc
          ]);

        cmakeFlags = [
          (lib.cmakeBool "WITH_LIBS_PRECOMPILED" true)
          (lib.cmakeBool "WITH_STATIC_LIBS" true)
          (lib.cmakeFeature "LIBDIR" "${self'.packages.libs}")

          (lib.cmakeBool "WITH_GHOST_X11" true)
          (lib.cmakeBool "WITH_GHOST_WAYLAND" true)
        ];

        buildInputs =
          x11deps
          ++ (with pkgs; [
            makeWrapper

            libGL
            libxkbcommon
          ])
          ++ lib.optionals (!stdenv.hostPlatform.isAarch64) (with pkgs.rocmPackages; [
            clr
            hiprt
          ])
          ++ lib.optionals cudaSupport (with pkgs; [
            (fetchFromGitHub {
              owner = "NVIDIA";
              repo = "optix-dev";
              tag = "v8.0.0";
              hash = "sha256-SXkXZHzQH8JOkXypjjxNvT/lUlWZkCuhh6hNCHE7FkY=";
            })
          ]);

        postInstall = ''
          tmpdir="$(mktemp --directory)"
          mv $out/* $tmpdir/.
          mkdir --parents $out/bin
          mkdir --parents $out/share
          mv $tmpdir/* $out/share/.
          makeWrapper $out/share/blender $out/bin/blender \
            --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath (
            x11deps
            ++ (with pkgs; [
              wayland
              libglvnd
              libdecor
              libxkbcommon
              mesa
            ])
            ++ lib.optionals (!stdenv.hostPlatform.isAarch64) (with pkgs.rocmPackages; [
              clr
            ])
          )}
        '';
        postFixup = lib.optionalString cudaSupport ''
          for program in $out/bin/blender $out/bin/.blender-wrapped; do
            addDriverRunpath "$program"
          done
        '';

        meta = {
          homepage = "https://www.dillongoostudios.com/gooengine";
          license = with lib.licenses; [gpl2Plus] ++ lib.optional cudaSupport nvidiaCudaRedist;

          maintainers = with lib.maintainers; [
            mcahyadit
          ];
          mainProgram = "blender";
        };
      });
    };
  };
}
