{
  description = "tsubu-cloud-cli";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zig = zig-overlay.packages.${system}."0.16.0";

        # tsubu-cloud-core は Zig パッケージ依存として取り込まれる (see
        # build.zig.zon)。Nix のサンドボックスビルドはネットワークアクセス
        # ができないため、依存tarballをここで事前fetchし、Zigのグローバル
        # パッケージキャッシュに配置することでオフラインビルドを維持する。
        tsubuCloudCorePkg = pkgs.fetchurl {
          url = "https://github.com/tsubu-cloud/tsubu-cloud-core/archive/33968bed52712051c1b9e60ec44d9aa8604c2947.tar.gz";
          hash = "sha256-AdkfDEZcsJlDOJIC9HYRIjFF+OMA0m1jjfDA5UGS+5o=";
        };
        tsubuCloudCoreCacheName = "tsubu_cloud_core-0.0.0-f59JhNNjAQAwUCwnRft3b01obTN2_p9fPI1EFWtsXo5b.tar.gz";

        targets = {
          "linux-x86_64-musl" = {
            crossPkgs = pkgs.pkgsCross.musl64.pkgsStatic;
            zigTarget = "x86_64-linux-musl";
            wasmtimeAsset = "x86_64-musl";
            wasmtimeHash = "sha256-Tjjk36zaFNe1hHSJKK8BSiZQKw+bCtNqXJMLBVfvjM4=";
          };
          "linux-aarch64-musl" = {
            crossPkgs = pkgs.pkgsCross.aarch64-multiplatform-musl.pkgsStatic;
            zigTarget = "aarch64-linux-musl";
            wasmtimeAsset = "aarch64-musl";
            wasmtimeHash = "sha256-z6AQtUC1wrIne4KAs1nx011xUz3TTosoJ3ec7lHVLmA=";
          };
        };

        mkTsubuCloudCli = { crossPkgs, zigTarget, wasmtimeAsset, wasmtimeHash }:
          let
            wasmtime = pkgs.stdenvNoCC.mkDerivation {
              pname = "wasmtime-c-api";
              version = "46.0.1";
              src = pkgs.fetchurl {
                url = "https://github.com/bytecodealliance/wasmtime/releases/download/v46.0.1/wasmtime-v46.0.1-${wasmtimeAsset}-c-api.tar.xz";
                hash = wasmtimeHash;
              };
              sourceRoot = "wasmtime-v46.0.1-${wasmtimeAsset}-c-api";
              installPhase = ''
                mkdir -p $out
                cp -r include $out/include
                mkdir -p $out/lib
                cp lib/libwasmtime.a $out/lib/
              '';
            };

            zlib = crossPkgs.zlib;
            openssl = crossPkgs.openssl;
            libpq = crossPkgs.libpq.override {
              curlSupport = false;
              gssSupport = false;
              inherit openssl zlib;
            };
          in
          crossPkgs.stdenv.mkDerivation {
            pname = "tsubu-cloud-cli";
            version = "0.0.0";
            src = ./.;

            nativeBuildInputs = [ zig crossPkgs.pkg-config ];
            buildInputs = [ crossPkgs.libunwind wasmtime libpq openssl zlib crossPkgs.xz ];

            dontConfigure = true;

            buildPhase = ''
              export HOME=$TMPDIR
              mkdir -p zig-global-cache/p
              cp ${tsubuCloudCorePkg} zig-global-cache/p/${tsubuCloudCoreCacheName}
              zig build --release=fast --prefix $out \
                --global-cache-dir $PWD/zig-global-cache \
                -Dtarget=${zigTarget} \
                -Dwasmtime-include=${wasmtime}/include \
                -Dwasmtime-lib=${wasmtime}/lib \
                -Dpq-lib=${libpq.dev or libpq}/lib \
                -Dlzma-lib=${crossPkgs.xz.out or crossPkgs.xz}/lib
            '';

            dontInstall = true;
          };
      in
      {
        packages = (builtins.mapAttrs (_: mkTsubuCloudCli) targets) // {
          default = self.packages.${system}."linux-x86_64-musl";
        };
      });
}
