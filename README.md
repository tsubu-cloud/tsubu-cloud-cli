# tsubu-cloud-cli

tsubu-cloud のローカル開発/デプロイ用 CLI (`tsubu_cloud_local`) です。WASM コンポーネントをローカルで実行したり、`tsubu.json` から WIT ファイルを生成したりします。

[`tsubu-cloud-core`](https://github.com/tsubu-cloud/tsubu-cloud-core) に依存しています。

## Build

```sh
zig build \
  -Dwasmtime-include=<wasmtime include dir> \
  -Dwasmtime-lib=<wasmtime lib dir> \
  -Dpq-lib=<libpq lib dir> \
  -Dlzma-lib=<liblzma lib dir>
```

## Usage

```sh
tsubu_cloud_local run <wasm-module> <config.json>
tsubu_cloud_local deploy <wasm-module> <config.json>
tsubu_cloud_local wit <config.json> [wit-dir]
```
