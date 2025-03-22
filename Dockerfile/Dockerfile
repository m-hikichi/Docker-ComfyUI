FROM python:3.12

# install comfy-cli
RUN pip install comfy-cli
# RUN comfy install

# install PyTorch
RUN pip install torch torchvision torchaudio

# clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git -b v0.3.27
