# Docker ComfyUI

ComfyUI を Docker で起動します。ComfyUI-Manager の有無を起動時に切り替えられます。

## 起動

`docker-compose` ディレクトリで実行します。

```powershell
cd docker-compose

# Manager あり（既定。docker-compose.override.yml が自動で適用される）
docker compose up -d --build

# まっさら（Manager なし。base 単独で起動）
docker compose -f docker-compose.yml up -d --build
```

リポジトリ直下から実行する場合、Manager ありは両ファイルを明示します（`-f` を付けると override は自動適用されないため）。

```powershell
docker compose -f docker-compose/docker-compose.yml -f docker-compose/docker-compose.override.yml up -d --build
```

ブラウザからは <http://localhost:8188> を開きます。

## 構成

- イメージは 1 つ（`comfy-ui:v0.19.0-manager`）で、Manager の有効 / 無効は実行時に切り替えます。
- **Manager あり**（override）では `custom_nodes` と `user` をホスト側に永続化するため、ComfyUI-Manager で入れたカスタムノードと Manager 設定は再起動後も残ります。
- **まっさら**（base 単独）では `custom_nodes` / `user` をマウントしないため、追加ノードのない素の状態で起動します。
- オフライン環境では、ビルド済みイメージ、手元のモデル、取得済みカスタムノードをそのまま使います。
