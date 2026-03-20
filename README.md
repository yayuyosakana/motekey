# pico-banana
ハッカソンチーム: picoばな奈

## Phase3 Bootstrap

このワークツリーでは `Package.swift` を基準に、以下4モジュールのビルド健全性を確認できます。

- `MoteKeyConfig`
- `MoteKeyShared`
- `MoteKeyHostAppCore`（画面ロジック除く）
- `MoteKeyKeyboardRuntimeCore`（UI層除く）

```bash
swift test
```
