# Docker ComfyUI

## 画像生成ワークフロー

番号付きのプロンプト入力欄、LoRAを2枠、任意のアップスケールを備えた標準ノードのみのワークフローです。
詳しいモデル配置と操作方法は[画像生成ガイド](docs/image-generation.md)を参照してください。

```text
workflows/
`-- generation/
    |-- stable-diffusion/
    |   `-- stable-diffusion-text-to-image.json
    `-- anima/
        `-- anima-text-to-image.json
```

用途別、その下をモデル別に分類します。他のブランチで追加する場合もこの分類に合わせてください。
ComfyUIのワークフロー一覧では `repository/` 以下に同じ構成で表示されます。

## 起動方法

リポジトリのルートで次を実行し、<http://localhost:8188> を開きます。

```powershell
docker compose -f docker-compose/docker-compose.yml up -d --build
```

イメージ作成済みなら `--build` の代わりに `--no-build` を使用できます。
Composeのモデル配置設定を変更した場合は、コンテナの再作成が必要です。
コンテナ内だけのアップロード画像や設定は永続化していないため、必要なものを事前にエクスポートしてください。
同梱ワークフローは読み取り専用です。編集結果はJSONとしてエクスポートして保存します。

## 画像からDanbooruタグを抽出

同梱の `workflows/tagging/image-to-danbooru-tags.json` は、画像を読み込み、
[WD14 Tagger](https://github.com/pythongosssss/ComfyUI-WD14-Tagger) でタグを抽出してノード内に表示します。
生成用チェックポイントは不要です。タグ推論はCPU版ONNX Runtimeで実行します。
既存のCompose設定はNVIDIA GPUを要求します。

### 実行手順

1. <http://localhost:8188> を開きます。
2. ワークフロー一覧の `repository/tagging/image-to-danbooru-tags` を開きます。一覧に出ない場合は `workflows/tagging/image-to-danbooru-tags.json` を画面へドラッグして読み込みます。
3. `LoadImage` で対象画像をアップロードします。
4. 実行すると、`WD14 Tagger` ノード内にカンマ区切りのタグが表示されます。表示欄からコピーできます。

### 抽出設定

| 設定 | 初期値 | 内容 |
| --- | --- | --- |
| `model` | `wd-v1-4-moat-tagger-v2` | 使用するタグ推論モデル |
| `threshold` | `0.35` | 一般タグの採用閾値。下げると候補が増えます |
| `character_threshold` | `0.85` | キャラクタータグの採用閾値 |
| `replace_underscore` | `false` | アンダースコアを保持します |
| `trailing_comma` | `false` | 末尾のカンマを付けません |
| `exclude_tags` | 空欄 | 除外するタグをカンマ区切りで指定します |

結果はモデルの推定です。ratingタグは出力されず、括弧はプロンプト用にエスケープされます。

### モデルの保存とオフライン利用

初回実行時にはHugging Faceからモデルとタグ一覧を自動ダウンロードします。
保存先はホストの `models/wd14_tagger/` で、コンテナを再作成しても再利用できます。
Dockerfileの `HF_HUB_OFFLINE=1` 等はWD14 Tagger独自のHTTPダウンロードを停止しません。
初回のDockerイメージビルドにもネットワーク接続が必要です。

ネットワークのない環境で実行する場合は、以下の2ファイルを事前に保存してください。

| ダウンロード元 | ホスト上の保存先 |
| --- | --- |
| [model.onnx](https://huggingface.co/SmilingWolf/wd-v1-4-moat-tagger-v2/resolve/main/model.onnx) | `models/wd14_tagger/wd-v1-4-moat-tagger-v2.onnx` |
| [selected_tags.csv](https://huggingface.co/SmilingWolf/wd-v1-4-moat-tagger-v2/resolve/main/selected_tags.csv) | `models/wd14_tagger/wd-v1-4-moat-tagger-v2.csv` |

`WD14Tagger` が見つからない場合は、変更後のDockerfileで再ビルドしたか確認してください。
起動ログは次のコマンドで確認できます。

```powershell
docker compose -f docker-compose/docker-compose.yml logs --tail 100 comfy-ui
```
