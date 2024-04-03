{
  description = "build flake";

  inputs.nixpkgs.url = "github:nixOs/nixpkgs";

  outputs = { self, nixpkgs }:
  let
    pkgs = (import nixpkgs {system = "x86_64-linux"; overlays = [];});
    #old-pkgs = (import old-nixpkgs {system = "x86_64-linux"; overlays = [];});

    pythonPkgs = pkgs.callPackage ./python-packages.nix { inherit pkgs; };
    conanpython = pkgs.python3.override { packageOverrides = pythonPkgs; };

    nodeEnv = pkgs.callPackage ./node-env.nix {};
    nodePkgs = pkgs.callPackage ./node-packages.nix { inherit nodeEnv; };

    deps =
      let
        llvm = pkgs.llvmPackages_14;
      in
      with pkgs; [
        glibc
        clang-tools
        llvm.clang
        llvm.libcxxabi
        llvm.libllvm
        llvm.bintools
        libidn
        libaio
        cmake
        gnumake
        protobuf
        python3
        antlr3
        conanpython.pkgs.conan
        nodePkgs."@diplodoc/cli"
        ninja
      ];

  in {
    packages.x86_64-linux = {
      ydb = pkgs.stdenv.mkDerivation {
        name = "ydb";
        buildInputs = deps;

        src = pkgs.fetchgit {
          url = "https://github.com/ydb-platform/ydb";
          rev = "1a93858f05b42a5a0c54b25b06b73fea9033c9ed"; # cmakebuild branch
          #sha256 = "sha256-MlqJOoMSRuYeG+jl8DFgcNnpEyeRgDCK2JlN9pOqBWA=";
        };

        configurePhase = ''
          mkdir tmp-build
          cd tmp-build
          cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=${./clang.toolchain} ..
        '';

        buildPhase = ''
          cd tmp-build
          ninja ydb/apps/ydbd/all
        '';

        installPhase = ''
          mkdir $out/bin
          cp ydb/apps/ydbd/ydbd $out/bin
          cp ydb/apps/ydb/ydb $out/bin
        '';
      };
    };

    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = deps;
    };
  };
}
