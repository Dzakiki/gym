import 'dart:io';

import 'package:flutter/services.dart';

/// Serves asset files straight from disk so tests validate the shipped files.
class FileAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.view(bytes.buffer);
  }
}
