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

  in {
    packages.x86_64-linux = {
    };

    devShells.x86_64-linux.default = pkgs.mkShell {
      packages =
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
      ];
    };
  };
}
