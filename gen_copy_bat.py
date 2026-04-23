import os

source_dir = r"C:\Users\asus\my\almadrasah\build\web"
dest_dir = r"C:\Users\asus\my\almadrasah\manar01"
bat_file = r"C:\Users\asus\my\almadrasah\manual_copy.bat"

commands = []
commands.append('@echo off')
commands.append(f'if not exist "{dest_dir}" mkdir "{dest_dir}"')

for root, dirs, files in os.walk(source_dir):
    rel_path = os.path.relpath(root, source_dir)
    target_root = os.path.join(dest_dir, rel_path)
    
    # Create directory
    if rel_path != '.':
        commands.append(f'if not exist "{target_root}" mkdir "{target_root}"')
    
    for file in files:
        src_file = os.path.join(root, file)
        dst_file = os.path.join(target_root, file)
        commands.append(f'copy /Y "{src_file}" "{dst_file}" > nul')

commands.append('echo Copy Done')

with open(bat_file, 'w', encoding='utf-8') as f:
    f.write('\n'.join(commands))

print(f"Generated {bat_file} with {len(commands)} commands.")
