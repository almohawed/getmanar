import 'dart:io';

void main() async {
  print('Current directory: ${Directory.current.path}');
  final sourcePath = r'C:\Users\asus\my\almadrasah\build\web';
  final destPath = r'C:\Users\asus\my\almadrasah\manar01';
  
  final sourceDir = Directory(sourcePath);
  final destDir = Directory(destPath);

  if (!await sourceDir.exists()) {
    print('ERROR: Source directory does not exist: $sourcePath');
    return;
  }
  
  if (!await destDir.exists()) {
    print('Creating destination directory: $destPath');
    await destDir.create(recursive: true);
  }

  print('Listing source files...');
  await for (final entity in sourceDir.list(recursive: true)) {
    print('Found: ${entity.path}');
    final relativePath = entity.path.substring(sourceDir.path.length + 1);
    final destEntityPath = '$destPath\\$relativePath';
    
    if (entity is Directory) {
      await Directory(destEntityPath).create(recursive: true);
    } else if (entity is File) {
      try {
        await entity.copy(destEntityPath);
        print('Copied: $relativePath');
      } catch (e) {
        print('Failed to copy $relativePath: $e');
      }
    }
  }
  print('Copy operation finished.');
}
