{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-appimage = {
      url = "github:ralismark/nix-appimage";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.treefmt-nix.flakeModule
        ./nix/packages.nix
      ];

      systems = ["x86_64-linux"];
      perSystem = {
        self',
        pkgs,
        system,
        config,
        ...
      }: {
        packages =
          {
            appimage = inputs.nix-appimage.lib.${system}.mkAppImage {
              program = "${self'.packages.default}/bin/blender";
            };
          }
          # I don't think most of these work as most libs are pre-compiled
          # ..left this one here for funsies
          // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
            appimage-x86-64-v3 = inputs.nix-appimage.lib.${system}.mkAppImage {
              program = "${self'.packages.x86-64-v3}/bin/blender";
            };
            appimage-x86-64-v4 = inputs.nix-appimage.lib.${system}.mkAppImage {
              program = "${self'.packages.x86-64-v4}/bin/blender";
            };
            x86-64-v3 = self'.packages.default.overrideAttrs (finalAttrs: previousAttrs: {
              cmakeFlags =
                previousAttrs.cmakeFlags
                ++ [
                  (pkgs.lib.cmakeFeature "X86_64_MICROARCH_LEVEL" "v3")
                ];
            });
            x86-64-v4 = self'.packages.default.overrideAttrs (finalAttrs: previousAttrs: {
              cmakeFlags =
                previousAttrs.cmakeFlags
                ++ [
                  (pkgs.lib.cmakeFeature "X86_64_MICROARCH_LEVEL" "v4")
                ];
            });
          };

        devShells.default = pkgs.mkShell {
          inputsFrom = [config.treefmt.build.devShell];
          packages = with pkgs; [
            nixd

            vscode-json-langserver
          ];
        };

        treefmt = {
          programs = {
            statix.enable = true;
            alejandra.enable = true;
            prettier.enable = true;
          };
        };
      };
    };
}
