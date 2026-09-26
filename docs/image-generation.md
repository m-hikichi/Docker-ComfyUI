# 画像生成ガイド

## モデルを配置する

| 対象 | ホスト上の配置先 |
| --- | --- |
| SDXL / Illustriousチェックポイント | `models/Illustrious/Checkpoint/` |
| SDXL / Illustrious LoRA（任意） | `models/Illustrious/LoRA/` |
| Anima拡散モデル | `models/Anima/diffusion_models/anima-base-v1.0.safetensors` |
| Animaテキストエンコーダー | `models/Anima/text_encoders/qwen_3_06b_base.safetensors` |
| Anima VAE | `models/Anima/vae/qwen_image_vae.safetensors` |
| Anima LoRA（任意） | `models/Anima/loras/` |
| 拡大モデル（任意） | `models/upscale_models/` |

Animaの3ファイルは[公式モデル一覧](https://huggingface.co/circlestone-labs/Anima/tree/main/split_files)から取得できます。
モデルファイルは同梱・自動ダウンロードしません。Anima LoRAはComfyUIでは `anima/ファイル名` と表示されます。
異なるモデル系統のLoRAを混用しないでください。

## 最初の1枚

1. [README](../README.md)に従ってComfyUIを起動します。
2. ワークフロー一覧の `repository/generation/` からモデルに合ったJSONを開きます。
3. `01 モデル / LoRA` で生成モデルを選択します。Animaは拡散モデル・テキストエンコーダー・VAEの3つを選択し、CLIPのtypeは `stable_diffusion` を維持します。
4. `02 プロンプト入力` の例文を変更します。最初は外見・服装・背景だけを変更し、不要な欄は空欄にしてください。
5. 実行します。初期状態は1024×1024、1枚、LoRAなし、拡大なしです。
6. `06 保存` の上側で元画像、下側で最終画像を確認します。PNGは `output/generation/stable-diffusion/` または `output/generation/anima/` に保存されます。

ファイルが一覧に出ない場合は配置先とComposeのマウントを確認し、モデル一覧を更新してください。

## プロンプトを組み立てる

### Anima Base v1

6欄の接続で公式のタグ順を固定しています。手動で並べ替える必要はありません。

| 順番 | 入力欄 | 入れる内容 |
| --- | --- | --- |
| 01 | 品質 / メタ / 年 / 安全性 | 品質、年代、画像の種類、安全性のタグ |
| 02 | 人数 / 主体 | 人数や主体を表すタグ |
| 03 | キャラクター | 固有キャラクター名。オリジナルなら空欄 |
| 04 | 作品名 | 登場作品名。不要なら空欄 |
| 05 | 作者 | 画風を指定する作者タグ。各名前の先頭に `@`。不要なら空欄 |
| 06 | 一般タグ | 外見、服装、ポーズ、構図、背景、光など |

タグは小文字・カンマ区切りで入力し、単語間は空白にします。`score_7` 等のスコアタグだけはアンダースコアを保持します。
自然文は06へ追記できます。タグの意味や誤字を自動判定する機能ではありません。
空欄は結合結果で空行になり、順序は保たれます。実行後に `結合済みPositive` を確認できます。

根拠: [Anima公式モデルカードのPrompting / Tag order](https://huggingface.co/circlestone-labs/Anima#prompting)。
初期設定はBase v1向けの30 steps / CFG 4 / Euler / simpleです。
AestheticではPositive・Negativeの `score_*` を外してください。TurboはCFG 1・8～12 stepsなど別設定が必要です。
モデル名を差し替えるだけで全派生モデルへ対応するものではありません。

### Stable Diffusion XL / Illustrious

品質・画風 → 主体・人数 → キャラクター・作品 → 外見・服装 → ポーズ・構図 → 背景・光の順で結合します。
入力を整理するための順番であり、全SDXLモデル共通の公式ルールではありません。
モデル指定の品質タグやトリガーがあれば対応する欄へ入力してください。AnimaやPonyのスコアタグは自動追加しません。
初期値は24 steps / CFG 5 / DPM++ 2M / Karrasです。モデル推奨設定を優先してください。
このテンプレートはSDXL / Illustrious向けで、SD1.5・SD3・FLUX用ではありません。

### PositiveとNegative

Positiveには描きたい内容、Negativeには避けたい特徴を書きます。
たとえば服を赤から青に変える場合は、服装欄の `red shirt` を `blue shirt` へ変更します。
相反する特徴を複数の欄に入れないようにしてください。
seedは初期状態で固定です。同じseedでプロンプトの差を比べ、別案を試すときにseedを変えます。

## LoRAを使う

1. 対応モデル用のLoRAを配置し、`LoRA 1` のファイルを選択します。
2. ノードを右クリックし `Mode > Always` でバイパスを解除します。選択後の `Ctrl+B` でも切り替えられます。
3. 配布元指定のトリガー語を、キャラクターなら03、服装・効果なら対応する欄へ入力します。
4. 強度は初期値0.7から配布元の推奨に合わせて調整します。2つ目も同様に有効化できます。

未使用の枠は `Mode > Bypass` に戻します。`Never` は接続を切るため使用しません。
ファイル未選択で有効化すると入力エラーになります。無効の枠はファイル未配置で構いません。
SDXLはMODELとCLIPの両方、AnimaはMODELだけに適用します。
Turbo等の生成条件を変えるLoRAには、配布元の追加設定も必要です。

## アップスケールする

`05 アップスケール` のA・Bはどちらも初期状態でバイパスです。

| 方法 | 操作 | 特徴 |
| --- | --- | --- |
| A: 2倍拡大 | Aを `Mode > Always` に変更 | 追加モデル不要のLanczos補間。`scale_by` で倍率を調整 |
| B: モデルで拡大 | B用モデルを選び、Bを `Mode > Always` に変更 | 学習済みアップスケーラー。倍率はモデル固有 |
| 拡大なし | A・Bとも `Mode > Bypass` | 元サイズで保存 |

Bには `UpscaleModelLoader` が対応する画像アップスケールモデルを配置してください。
Bが無効ならモデルを選ぶ必要はなく、そのロードは実行されません。
Aは補間であり、AIによる細部の復元ではありません。Bも必ず画質が改善するとは限りません。
両方有効なら倍率が掛け合わされるため、通常は片方だけを使ってください。再サンプリング型Hires Fixは含みません。
同じ生成条件のまま拡大だけを切り替えると、キャッシュが残っていれば元の生成結果を再利用できます。

## メモリと検証

最初は1枚から始め、メモリ不足なら生成サイズを下げます。Animaは幅・高さを16の倍数、SDXLは8の倍数に保ちます。
Animaでは必要に応じて `CLIPLoader.device=cpu` を使用できます。
生成モデル・LoRA・拡大モデルは同梱していないため、実画像の品質と互換性は使用モデルを配置して確認してください。

開発者向けの検証は、ComfyUIを起動したWindows環境で `./tests/verify-generation.ps1` を実行します。
Edgeの独立した一時プロファイルを使い、実際のフロントエンドでプロンプト順とLoRA・拡大の切替を検査します。
生成キューには送信しません。必要なら `-Browser` と `-ComfyUrl` で環境を指定できます。
