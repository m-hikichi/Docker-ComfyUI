#!/usr/bin/env bash
set -euo pipefail

# 旧形式の ComfyUI-Manager を使う ComfyUI バージョン向けに、
# ビルド時に退避しておいた Manager を custom_nodes に配置する。
legacy_manager_src="/opt/comfyui-manager"
legacy_manager_dst="/ComfyUI/custom_nodes/comfyui-manager"

# custom_nodes はカスタムノード、user は Manager 設定やスナップショットを
# ホスト側 volume に永続化するためのディレクトリ。
mkdir -p /ComfyUI/custom_nodes /ComfyUI/user

# custom_nodes が空の初回起動時だけ Manager をコピーする。
# 既にユーザーが Manager を置いている場合は上書きしない。
if [ -d "${legacy_manager_src}" ] \
  && [ ! -d "${legacy_manager_dst}" ] \
  && [ ! -d "/ComfyUI/custom_nodes/ComfyUI-Manager" ]; then
  echo "Installing ComfyUI-Manager into /ComfyUI/custom_nodes/comfyui-manager"
  cp -a "${legacy_manager_src}" "${legacy_manager_dst}"
fi

# ComfyUI-Manager のインストール操作は、Manager 側の安全ポリシーにより
# network_mode=personal_cloud かつ security_level=normal 以下でないと拒否される。
# 以前の起動で public などが永続化されていても、カスタムノードを入れられる
# 標準状態に戻す。
manager_config="/ComfyUI/user/__manager/config.ini"
mkdir -p "$(dirname "${manager_config}")"
touch "${manager_config}"

set_manager_config() {
  key="$1"
  value="$2"

  if grep -q "^[[:space:]]*${key}[[:space:]]*=" "${manager_config}"; then
    sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "${manager_config}"
  else
    printf '%s = %s\n' "${key}" "${value}" >> "${manager_config}"
  fi
}

set_manager_config network_mode personal_cloud
set_manager_config security_level normal

# 新形式の ComfyUI-Manager が ComfyUI 本体に組み込まれている場合は、
# 起動コマンドへ --enable-manager を自動追加する。
# 既に指定されている場合や COMFYUI_ENABLE_MANAGER=0 の場合は何もしない。
if [ "$#" -ge 2 ] \
  && [ "$1" = "python" ] \
  && [ "$2" = "main.py" ] \
  && [ -f /opt/comfyui-core-manager ] \
  && [ "${COMFYUI_ENABLE_MANAGER:-1}" = "1" ]; then
  already_enabled=0
  for arg in "$@"; do
    if [ "${arg}" = "--enable-manager" ]; then
      already_enabled=1
      break
    fi
  done

  if [ "${already_enabled}" = "0" ]; then
    set -- "$@" --enable-manager
  fi
fi

exec "$@"
