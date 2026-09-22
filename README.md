# Docker ComfyUI

## ワークフローの配置

`workflows/` は用途別に分け、モデルに依存するワークフローはその下をモデル別に分けます。
新しいワークフローを他のブランチで追加する場合も、この分類に合わせてください。

```text
workflows/
`-- inpaint/
|   |-- stable-diffusion/
|   |   `-- stable-diffusion-masked-image-inpaint.json
|   `-- anima/
|       `-- anima-masked-image-inpaint.json
```

ComfyUIのワークフロー一覧には、`repository/` 以下に同じフォルダー構成で表示されます。

## Animaで画像の一部を修正

`workflows/inpaint/anima/anima-masked-image-inpaint.json` はAnima Base v1用のマスク付きimg2imgです。
SDXL版と同じく、指定範囲を再生成し、マスク外を元画像から保持します。
Animaはチェックポイント1個ですべてを読み込む構成ではなく、次の3種類を別々に読み込みます。

| 役割 / ノード | 必要なファイルとホスト上の配置先 |
| --- | --- |
| 拡散モデル / `UNETLoader` | `models/Anima/diffusion_models/anima-base-v1.0.safetensors` |
| テキストエンコーダー / `CLIPLoader` | `models/Anima/text_encoders/qwen_3_06b_base.safetensors` |
| VAE / `VAELoader` | `models/Anima/vae/qwen_image_vae.safetensors` |

取得元: [Anima公式モデル一覧](https://huggingface.co/circlestone-labs/Anima/tree/main/split_files)。
ファイルは自動ダウンロードされません。3種類をそれぞれ上記フォルダーへ配置してください。
同じエンコーダー・VAEに対応するAnima派生モデルも、拡散モデルの選択を変えて利用する構成です。
異なる構成の派生モデルやGGUF版はこのワークフローの対象外です。

1. モデル配置後、次のコマンドでComposeの新しいマウント設定を反映します。
2. <http://localhost:8188> で `repository/inpaint/anima/anima-masked-image-inpaint` を開きます。
3. 3つのローダーで配置したファイルを選択します。`CLIPLoader.type` は公式ワークフローと同じ `stable_diffusion`、`weight_dtype` は `default` のまま使用します。
4. `LoadImage` に元画像を読み込み、右クリックの `Open in MaskEditor` で修正範囲を塗って保存・適用します。
5. `Positive Prompt` に修正後の内容を書き、実行します。結果は `output/inpaint/anima/` に保存されます。

```powershell
docker compose -f docker-compose/docker-compose.yml up -d --no-build
```

イメージをまだビルドしていない場合は `--no-build` を `--build` に変更してください。
コンテナの再作成で、コンテナ内だけにあるアップロード画像・設定は失われるため、必要な画像やワークフローを事前にエクスポートしてください。

初期値は `steps=30`、`cfg=4`、`sampler=euler`、`scheduler=simple`、`denoise=0.55` です。
`denoise` を下げると元画像に近い修正、上げると大きな描き直しになります。
Turbo LoRAは使いません。標準のAnima Base v1向け設定です。
画像の幅・高さは16の倍数（例: 1024×1024、832×1216）を使用してください。
VAEやモデル内部のサイズ調整によるマスク位置ずれを避けるためです。
VRAM不足の場合は画像を小さくするか、`CLIPLoader.device` を `cpu` に変更してください。

モデル構成と通常生成の設定は[ComfyUI公式Animaワークフロー](https://github.com/Comfy-Org/workflow_templates/blob/main/templates/image_anima_base_v1.json)に合わせています。
本ワークフローはそのローダー構成を部分修正用に組み合わせたもので、専用のinpainting学習済みモデルではありません。

## Stable Diffusion用の部分修正（SDXL / Illustrious）

`workflows/inpaint/stable-diffusion/stable-diffusion-masked-image-inpaint.json` は、元画像をVAEでエンコードし、
マスクで指定した部分を再生成して元画像へ合成するワークフローです。
ComfyUI標準ノードのみを使い、通常のIllustrious / SDXLチェックポイントで動作する構成です。
専用inpaintingモデルや追加カスタムノードは不要です。

### 準備と実行

1. 使用する通常のチェックポイント（`.safetensors`）を `models/Illustrious/Checkpoint/` に配置します。できれば元画像を生成したモデルを使用してください。モデルはこのリポジトリに含まれません。
2. 下記の起動コマンドでComfyUIを起動し、<http://localhost:8188> を開きます。すでにこのリポジトリのDocker設定で起動済みなら、このワークフロー追加のための再ビルドは不要です。
3. ワークフロー一覧から `repository/inpaint/stable-diffusion/stable-diffusion-masked-image-inpaint` を開くか、JSONファイルを画面へドラッグします。
4. `Load Checkpoint` でモデルを選択し、`LoadImage` で修正したい画像をアップロードします。
5. `LoadImage` の画像を右クリックして `Open in MaskEditor` を開き、変更したい範囲を塗って保存・適用します。マスクを描かないと画像は修正されません。
6. `Positive Prompt` に修正後の内容と元画像の画風を入力します。元のプロンプトを土台に、変更したい特徴を書き換えると調整しやすくなります。`Negative Prompt` は必要に応じて編集します。
7. 実行すると、`SaveImage` に結果が表示され、ホストの `output/inpaint/` にPNGが保存されます。元の画像ファイルは上書きしません。実行時の `Mask Preview` は白が修正対象、黒が保持対象です。

```powershell
docker compose -f docker-compose/docker-compose.yml up -d --build
```

### 修正の強さと注意点

| 設定 | 初期値 | 調整の目安 |
| --- | --- | --- |
| `KSampler.denoise` | `0.55` | 小さな修正は `0.25～0.45`、大きな描き直しは `0.65～0.85` から調整 |
| `steps` | `24` | 使用モデルの推奨設定に合わせて調整 |
| `cfg` | `5` | 使用モデルの推奨設定に合わせて調整 |
| `seed` | `0` / `fixed` | 固定して設定差を比較し、別案が必要なら変更 |

画像は幅・高さともに8の倍数（例: 1024×1024、832×1216）を使用してください。
通常のSDXL VAEはそれ以外の端数を切り詰めるため、マスクと合成位置がずれる場合があります。
これは画像全体を処理する構成なので、大きな画像ほどVRAMを使います。

最後の `ImageCompositeMasked` でマスク外の画素を元画像から保持します。
マスクの境界が目立つ場合は、MaskEditorで境界を柔らかくし、修正対象の周囲も少し含めてください。
半透明のマスク部分は元画像と生成結果が混ざります。
この構成は元画像を保持した部分修正向けで、専用inpaintingモデル用の追加条件付けは行いません。
FLUXやQwenなど異なるモデル構成は対象外です。

マスク編集の操作は [ComfyUI公式のinpaint例](https://comfyanonymous.github.io/ComfyUI_examples/inpaint/) も参照できます。
