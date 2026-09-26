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

リポジトリのルートで次を実行し、<http://localhost:8188> を開きます。

```powershell
docker compose -f docker-compose/docker-compose.yml up -d --build
```

イメージ作成済みなら `--build` の代わりに `--no-build` を使用できます。
Composeのモデル配置設定を変更した場合は、コンテナの再作成が必要です。
コンテナ内だけのアップロード画像や設定は永続化していないため、必要なものを事前にエクスポートしてください。
同梱ワークフローは読み取り専用です。編集結果はJSONとしてエクスポートして保存します。

このブランチは通常の画像生成用です。タグ抽出は `feat/image-to-danbooru-tags`、部分修正は `feat/masked-image-inpaint` で管理します。
