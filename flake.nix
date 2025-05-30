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
        llvm = pkgs.llvmPackages_18;
      in
      with pkgs; [
        ccls
        llvm.clang-tools
        llvm.clang
        #llvm.libcxxabi
        llvm.libllvm
        llvm.bintools
        libidn
        libaio
        cmake
        gnumake
        protobuf
        python3
        python3.pkgs.python-lsp-server
        antlr3
        conanpython.pkgs.conan
        nodePkgs."@diplodoc/cli"
        ninja
      ];

    shell-deps = [pkgs.glibc] ++ deps;

  in {
    packages.x86_64-linux = {
      ydb-dev = pkgs.stdenv.mkDerivation {
        name = "ydb";
        buildInputs = deps;

        src = pkgs.fetchgit {
          url = "https://github.com/ydb-platform/ydb";
          rev = "1a93858f05b42a5a0c54b25b06b73fea9033c9ed";
          sha256 = "sha256-eqYWfV77eCeRfp+lNcERQ8QJdrrcQwUpsOVBpBKmBA4=";
        };

        configurePhase = ''
          true;
        '';

        buildPhase = ''
          ls
          env YA_CACHE_DIR=$PWD/.ya-cache python ya make -r ydb/apps/ydbd ydb/apps/ydb
        '';

        installPhase = ''
          mkdir $out/bin
          cp ydb/apps/ydbd/ydbd $out/bin
          cp ydb/apps/ydb/ydb $out/bin
        '';
      };

      ydb-cmake = pkgs.stdenv.mkDerivation {
        name = "ydb";
        buildInputs = deps;

        src = pkgs.fetchgit {
          url = "https://github.com/ydb-platform/ydb";
          rev = "06f8150219a226f7955787eb5212db4020fe1f42"; # cmakebuild branch
          sha256 = "sha256-oGnWGiCjLCUU7Toy0SdCHb2wTooC1YFiMwwejkgCgMI=";
        };

        configurePhase = ''
          mkdir tmp-build
          cd tmp-build
          mkdir conan-executable
          ln -s ${conanpython.pkgs.conan}/bin/conan conan-executable/Conan
          export PATH=$PATH:$PWD/conan-executable
          export CONAN_USER_HOME=$PWD
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

      #default = ydb-cmake;
    };

    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = shell-deps;
    };
  };
}
