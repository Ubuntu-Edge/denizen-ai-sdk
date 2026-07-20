import urllib.request
import json
import zipfile
import os

req = urllib.request.Request('https://api.github.com/repos/asg017/sqlite-vec/releases/tags/v0.1.1')
with urllib.request.urlopen(req) as response:
    data = json.loads(response.read().decode())
    
for asset in data['assets']:
    print(asset['name'])
