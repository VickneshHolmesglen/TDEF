import json
import urllib.request
import urllib.error
import time
import os
import shutil
import sys
import random

COMFYUI_URL = "http://127.0.0.1:8188"
OUTPUT_DIR = r"G:\ComfyUI\output"
ASSETS_DIR = r"G:\TDef\assets"

def check_comfyui_running():
    try:
        urllib.request.urlopen(f"{COMFYUI_URL}/system_stats", timeout=3)
        return True
    except:
        return False

def queue_prompt(prompt_workflow):
    data = json.dumps({"prompt": prompt_workflow}).encode("utf-8")
    req = urllib.request.Request(f"{COMFYUI_URL}/prompt", data=data)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())

def get_history(prompt_id):
    try:
        with urllib.request.urlopen(f"{COMFYUI_URL}/history/{prompt_id}") as response:
            return json.loads(response.read())
    except:
        return {}

def wait_for_completion(prompt_id, timeout=600):
    print(f"Waiting for generation (prompt_id: {prompt_id})...")
    start = time.time()
    while time.time() - start < timeout:
        time.sleep(3)
        history = get_history(prompt_id)
        if prompt_id in history:
            outputs = history[prompt_id].get("outputs", {})
            if outputs:
                print(" Done!")
                return outputs
            else:
                print(".", end="", flush=True)
        else:
            print(".", end="", flush=True)
    raise TimeoutError("Generation timed out after 600 seconds")

def build_workflow(prompt, negative_prompt="", width=512, height=512, steps=20, seed=None):
    if seed is None:
        seed = random.randint(0, 999999999)

    return {
        "1": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {
                "ckpt_name": "DreamShaperXL_Turbo_v2_1.safetensors"
            }
        },
        "2": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "text": prompt,
                "clip": ["1", 1]
            }
        },
        "3": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "text": negative_prompt or "blurry, bad quality, watermark, text, ugly",
                "clip": ["1", 1]
            }
        },
        "4": {
            "class_type": "EmptyLatentImage",
            "inputs": {
                "width": width,
                "height": height,
                "batch_size": 1
            }
        },
        "5": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["1", 0],
                "positive": ["2", 0],
                "negative": ["3", 0],
                "latent_image": ["4", 0],
                "seed": seed,
                "steps": steps,
                "cfg": 7.0,
                "sampler_name": "euler_ancestral",
                "scheduler": "normal",
                "denoise": 1.0
            }
        },
        "6": {
            "class_type": "VAEDecode",
            "inputs": {
                "samples": ["5", 0],
                "vae": ["1", 2]
            }
        },
        "7": {
            "class_type": "SaveImage",
            "inputs": {
                "images": ["6", 0],
                "filename_prefix": "asset"
            }
        }
    }

def get_latest_output_image():
    """Find the most recently created image in ComfyUI output folder."""
    images = []
    for f in os.listdir(OUTPUT_DIR):
        if f.endswith(".png") or f.endswith(".jpg") or f.endswith(".jpeg"):
            full_path = os.path.join(OUTPUT_DIR, f)
            images.append((os.path.getmtime(full_path), full_path, f))
    if not images:
        return None
    images.sort(reverse=True)
    return images[0]

def move_to_assets(outputs, asset_name):
    os.makedirs(ASSETS_DIR, exist_ok=True)
    moved = []

    # Try getting image from API outputs first
    for node_id, node_output in outputs.items():
        if "images" in node_output:
            for image in node_output["images"]:
                src = os.path.join(OUTPUT_DIR, image["filename"])
                if os.path.exists(src):
                    ext = os.path.splitext(image["filename"])[1]
                    dst = os.path.join(ASSETS_DIR, f"{asset_name}{ext}")
                    counter = 1
                    while os.path.exists(dst):
                        dst = os.path.join(ASSETS_DIR, f"{asset_name}_{counter}{ext}")
                        counter += 1
                    shutil.copy2(src, dst)
                    moved.append(dst)
                    print(f"Saved: {dst}")
                    return moved

    # Fallback: grab the most recently modified image in output folder
    print("Trying fallback: grabbing latest image from output folder...")
    latest = get_latest_output_image()
    if latest:
        mtime, src, filename = latest
        ext = os.path.splitext(filename)[1]
        dst = os.path.join(ASSETS_DIR, f"{asset_name}{ext}")
        counter = 1
        while os.path.exists(dst):
            dst = os.path.join(ASSETS_DIR, f"{asset_name}_{counter}{ext}")
            counter += 1
        shutil.copy2(src, dst)
        moved.append(dst)
        print(f"Saved: {dst}")
    else:
        print("No images found in output folder.")

    return moved

def generate(prompt, asset_name, negative_prompt="", width=512, height=512, steps=20):
    print(f"\nGenerating: {asset_name}")
    print(f"Prompt: {prompt}")

    if not check_comfyui_running():
        print("ComfyUI is not running. Starting it now...")
        os.system(r"start /B G:\TDef\tools\start_comfyui.bat")
        print("Waiting 20 seconds for ComfyUI to initialize...")
        time.sleep(20)
        if not check_comfyui_running():
            raise RuntimeError("ComfyUI failed to start. Please start it manually.")

    workflow = build_workflow(prompt, negative_prompt, width, height, steps)
    result = queue_prompt(workflow)
    prompt_id = result["prompt_id"]
    print(f"Queued with prompt_id: {prompt_id}")
    outputs = wait_for_completion(prompt_id)
    return move_to_assets(outputs, asset_name)

# CLI usage
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python generate_asset.py \"prompt\" \"asset_name\" [width] [height] [steps]")
        print("Example: python generate_asset.py \"top down tower, fantasy, game asset\" \"tower_basic\" 512 512 20")
        sys.exit(1)

    prompt = sys.argv[1]
    asset_name = sys.argv[2]
    width = int(sys.argv[3]) if len(sys.argv) > 3 else 512
    height = int(sys.argv[4]) if len(sys.argv) > 4 else 512
    steps = int(sys.argv[5]) if len(sys.argv) > 5 else 20

    generate(prompt, asset_name, width=width, height=height, steps=steps)