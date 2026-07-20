import os
import urllib.request
import zipfile
import tarfile
import shutil

VERSION = "v0.1.1"
URL = f"https://github.com/asg017/sqlite-vec/releases/download/{VERSION}/sqlite-vec-{VERSION.lstrip('v')}-loadable-windows-x86_64.zip"
ZIP_PATH = "sqlite-vec-windows.zip"
TARGET_DIR = os.path.join("build", "windows_deps")

def main():
    if not os.path.exists(TARGET_DIR):
        os.makedirs(TARGET_DIR)
        
    print(f"Downloading {URL}...")
    
    try:
        urllib.request.urlretrieve(URL, ZIP_PATH)
    except Exception as e:
        print(f"Failed to download zip: {e}")
        print("Trying tar.gz instead...")
        # Fallback to tar.gz just in case
        tar_url = URL.replace(".zip", ".tar.gz")
        urllib.request.urlretrieve(tar_url, ZIP_PATH)

    print("Extracting...")
    # It might be a zip or tar.gz. The fallback saved to ZIP_PATH but could be tar.
    try:
        with zipfile.ZipFile(ZIP_PATH, 'r') as zip_ref:
            zip_ref.extractall("temp_extract")
    except zipfile.BadZipFile:
        with tarfile.open(ZIP_PATH, "r:gz") as tar_ref:
            def is_within_directory(directory, target):
                
                abs_directory = os.path.abspath(directory)
                abs_target = os.path.abspath(target)
            
                prefix = os.path.commonprefix([abs_directory, abs_target])
                
                return prefix == abs_directory
            
            def safe_extract(tar, path=".", members=None, *, numeric_owner=False):
            
                for member in tar.getmembers():
                    member_path = os.path.join(path, member.name)
                    if not is_within_directory(path, member_path):
                        raise Exception("Attempted Path Traversal in Tar File")
            
                tar.extractall(path, members, numeric_owner=numeric_owner) 
                
            
            safe_extract(tar_ref, "temp_extract")

    # Find vec0.dll
    dll_found = False
    for root, _, files in os.walk("temp_extract"):
        for f in files:
            if f == "vec0.dll":
                shutil.copy(os.path.join(root, f), os.path.join(TARGET_DIR, "vec0.dll"))
                dll_found = True
                print(f"Copied vec0.dll to {TARGET_DIR}")
                break

    if not dll_found:
        print("ERROR: vec0.dll not found in archive!")
    
    # Cleanup
    if os.path.exists(ZIP_PATH):
        os.remove(ZIP_PATH)
    if os.path.exists("temp_extract"):
        shutil.rmtree("temp_extract")

if __name__ == "__main__":
    main()
