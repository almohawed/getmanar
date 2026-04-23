import shutil
import os

src = 'build/web'
dst = 'manar01'

try:
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    with open('copy_success.txt', 'w') as f:
        f.write('success')
    print("Copy completed")
except Exception as e:
    with open('copy_error.txt', 'w') as f:
        f.write(str(e))
    print(f"Error: {e}")
