import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  static ImageStorageService? _instance;
  factory ImageStorageService() => _instance ??= ImageStorageService._();
  ImageStorageService._();

  Future<Directory> _imagesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/fuel_images');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _filename(int entryId) => 'fuel_$entryId.jpg';

  /// Save image file for a given entry ID. Returns saved path.
  Future<String> saveImage(int entryId, String sourcePath) async {
    final dir = await _imagesDir();
    final dest = File('${dir.path}/${_filename(entryId)}');
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  /// Delete image for a given entry ID.
  Future<void> deleteImage(int entryId) async {
    final dir = await _imagesDir();
    final file = File('${dir.path}/${_filename(entryId)}');
    if (await file.exists()) await file.delete();
  }

  /// Returns the image file if it exists, else null.
  Future<File?> getImage(int entryId) async {
    final dir = await _imagesDir();
    final file = File('${dir.path}/${_filename(entryId)}');
    return await file.exists() ? file : null;
  }

  /// Synchronous path computation (for widgets that check file existence themselves).
  Future<String> imagePath(int entryId) async {
    final dir = await _imagesDir();
    return '${dir.path}/${_filename(entryId)}';
  }
}
