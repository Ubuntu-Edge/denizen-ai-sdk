import urllib.request
import zipfile
import os
import shutil

def download():
    print("Downloading sqlite-vec amalgamation...")
    urllib.request.urlretrieve("https://github.com/asg017/sqlite-vec/releases/download/v0.1.1/sqlite-vec-0.1.1-amalgamation.zip", "vec.zip")
    
    with zipfile.ZipFile("vec.zip", 'r') as zip_ref:
        zip_ref.extractall("vec_temp")
        
    shutil.copy("vec_temp/sqlite-vec.c", "src/sqlite-vec.c")
    shutil.copy("vec_temp/sqlite-vec.h", "src/sqlite-vec.h")
    
    os.remove("vec.zip")
    shutil.rmtree("vec_temp")

    print("Downloading sqlite3 amalgamation...")
    # SQLite has a redirect, we need to use a Request object to follow it, but urllib handles basic 301/302
    try:
        urllib.request.urlretrieve("https://www.sqlite.org/2024/sqlite-amalgamation-3460000.zip", "sqlite.zip")
        with zipfile.ZipFile("sqlite.zip", 'r') as zip_ref:
            zip_ref.extractall(".")
        shutil.copy("sqlite-amalgamation-3460000/sqlite3.h", "src/sqlite3.h")
        shutil.copy("sqlite-amalgamation-3460000/sqlite3ext.h", "src/sqlite3ext.h")
        os.remove("sqlite.zip")
        shutil.rmtree("sqlite-amalgamation-3460000")
    except Exception as e:
        print("Failed to download sqlite3 amalgamation, skipping...", e)

    print("Done.")

if __name__ == '__main__':
    download()
