# pico-banana
ハッカソンチーム: picoばな奈

## Bootstrap Baseline

このリポジトリでは、`Package.swift` を基準に以下4モジュールの基盤健全性を確認できます。

- `MoteKeyConfig`
- `MoteKeyShared`
- `MoteKeyHostAppCore`（画面ロジック除く）
- `MoteKeyKeyboardRuntimeCore`（UI層除く）

## Quick Start

```bash
make bootstrap-check
```

上記コマンドは `scripts/bootstrap_check.sh` を呼び出し、基盤向けの再現可能な検証を実行します。

## 手動実行

```bash
./scripts/bootstrap_check.sh
```

## CI

GitHub Actions (`.github/workflows/bootstrap.yml`) でも同一コマンドを実行します。

- `pull_request`（`main` 向け）
- `push`（`main` / `codex/**`）
- `workflow_dispatch`（手動実行）
