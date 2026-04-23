import 'dart:io';

void main() async {
  final sourceDir = Directory(r'C:\Users\asus\my\almadrasah\build\web');
  final destDir = Directory(r'C:\Users\asus\my\almadrasah\manar01');

  if (!await sourceDir.exists()) {
    print('Source directory does not exist: ${sourceDir.path}');
    return;
  }

  if (await destDir.exists()) {
    print('Deleting existing destination directory...');
    await destDir.delete(recursive: true);
  }
  
  print('Creating destination directory...');
  await destDir.create(recursive: true);

  print('Copying files...');
  await copyDirectory(sourceDir, destDir);
  print('Copy completed successfully.');
}

Future<void> copyDirectory(Directory source, Directory destination) async {
  await for (final entity in source.list(recursive: false)) {
    if (entity is Directory) {
      final newDirectory = Directory(
          destination.path + Platform.pathSeparator + entity.path.split(Platform.pathSeparator).last);
      await newDirectory.create();
      await copyDirectory(entity.absolute, newDirectory);
    } else if (entity is File) {
      final newFile = File(
          destination.path + Platform.pathSeparator + entity.path.split(Platform.pathSeparator).last);
      await entity.copy(newFile.path);
    }
  }
}
