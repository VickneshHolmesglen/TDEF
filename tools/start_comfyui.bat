@echo off
echo Starting ComfyUI with ZLUDA for AMD RX 6800 XT...
set HIP_PATH=C:\Program Files\AMD\ROCm\6.2
set PATH=C:\Program Files\AMD\ROCm\6.2\bin;%PATH%
set ZLUDA_COMGR_LOG_LEVEL=1
cd G:\ComfyUI
python main.py %*