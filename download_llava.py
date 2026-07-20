import urllib.request
import os

base_url = "https://raw.githubusercontent.com/ggerganov/llama.cpp/master/examples/llava/"
files = ["clip.h", "clip.cpp", "llava.h", "llava.cpp"]
out_dir = "packages/llama_flutter_android/android/src/main/cpp/llama.cpp/examples/llava"

os.makedirs(out_dir, exist_ok=True)

for file in files:
    print(f"Downloading {file}...")
    try:
        url = base_url + file
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            content = response.read()
            with open(os.path.join(out_dir, file), "wb") as f:
                f.write(content)
        print(f"✅ Downloaded {file}")
    except Exception as e:
        print(f"❌ Failed to download {file}: {e}")
