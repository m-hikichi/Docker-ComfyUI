FROM python:3.12

ARG COMFYUI_VERSION=v0.5.0

# git が必要（cloneするため）
RUN apt-get update && apt-get install -y --no-install-recommends git \
  && rm -rf /var/lib/apt/lists/*

# PyTorch（NVIDIAでGPUを使うなら、通常は extra-index-url が必要です）
# ComfyUI README でも NVIDIA 用インストール例が案内されています :contentReference[oaicite:3]{index=3}
# ※CUDAの版はホスト/ドライバに合わせて調整してください
RUN pip install --no-cache-dir torch torchvision torchaudio \
    --extra-index-url https://download.pytorch.org/whl/cu130

# ComfyUI 本体
RUN git clone --depth 1 --branch ${COMFYUI_VERSION} https://github.com/comfyanonymous/ComfyUI.git /ComfyUI

WORKDIR /ComfyUI

# 依存関係（これが重要）
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8188
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
