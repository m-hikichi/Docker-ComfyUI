FROM python:3.12

ARG COMFYUI_VERSION=v0.11.0
# CUDA 13.0 wheels を使う想定。環境に合わせて cu128 / cu121 / cpu などに変更してください。
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu130

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1 \
    DIFFUSERS_OFFLINE=1

# runtime で必要になりがちなライブラリ（opencv / av / 動画周り）
RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      ffmpeg \
      libgl1 \
      libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# ComfyUI 本体
RUN git clone --depth 1 --branch ${COMFYUI_VERSION} https://github.com/Comfy-Org/ComfyUI.git /ComfyUI

WORKDIR /ComfyUI

# 先に CUDA 版 torch を入れておく（requirements 内の torch を満たすため）
RUN pip install --no-cache-dir --index-url ${TORCH_INDEX_URL} \
      torch torchvision torchaudio

# 依存関係
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8188
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
