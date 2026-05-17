# Docker ComfyUI

ComfyUI-Manager 入りの ComfyUI を Docker で起動します。

```powershell
docker compose -f docker-compose/docker-compose.yml up -d --build
```

ブラウザからは <http://localhost:8188> を開きます。

`custom_nodes` と `user` はホスト側に永続化されるため、ComfyUI-Manager で入れたカスタムノードと Manager 設定は再起動後も残ります。オフライン環境では、ビルド済みイメージ、手元のモデル、取得済みカスタムノードをそのまま使います。
