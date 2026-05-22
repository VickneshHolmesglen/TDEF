import urllib.request, json

workflow = {
    "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "DreamShaperXL_Turbo_v2_1.safetensors"}},
    "2": {"class_type": "CLIPTextEncode", "inputs": {"text": "a red circle", "clip": ["1", 1]}},
    "3": {"class_type": "CLIPTextEncode", "inputs": {"text": "bad quality", "clip": ["1", 1]}},
    "4": {"class_type": "EmptyLatentImage", "inputs": {"width": 512, "height": 512, "batch_size": 1}},
    "5": {"class_type": "KSampler", "inputs": {"model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0], "seed": 42, "steps": 5, "cfg": 7.0, "sampler_name": "euler_ancestral", "scheduler": "normal", "denoise": 1.0}},
    "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
    "7": {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": "test"}}
}

data = json.dumps({"prompt": workflow}).encode("utf-8")
req = urllib.request.Request("http://127.0.0.1:8188/prompt", data=data)
req.add_header("Content-Type", "application/json")
try:
    with urllib.request.urlopen(req) as r:
        print("SUCCESS:", json.loads(r.read()))
except Exception as e:
    print("ERROR:", e.code)
    print("DETAIL:", e.read().decode())