FROM python:3.12

ARG COMFYUI_VERSION=v0.19.0
ARG COMFYUI_MANAGER_VERSION=main
# CUDA 13.0 wheels を使う想定。環境に合わせて cu128 / cu121 / cpu などに変更してください。
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu130

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

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

# ComfyUI-Manager
# Newer ComfyUI releases ship Manager in core and enable it via --enable-manager.
# Older releases still need the custom-node version, copied into the persistent
# custom_nodes mount by the entrypoint on first start.
RUN if [ -f manager_requirements.txt ]; then \
      pip install --no-cache-dir -r manager_requirements.txt && \
      touch /opt/comfyui-core-manager; \
    else \
      git clone --depth 1 --branch ${COMFYUI_MANAGER_VERSION} \
        https://github.com/Comfy-Org/ComfyUI-Manager.git /opt/comfyui-manager && \
      if [ -f /opt/comfyui-manager/requirements.txt ]; then \
        pip install --no-cache-dir -r /opt/comfyui-manager/requirements.txt; \
      fi; \
    fi

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN sed -i 's/\r$//' /docker-entrypoint.sh && chmod +x /docker-entrypoint.sh

EXPOSE 8188
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
