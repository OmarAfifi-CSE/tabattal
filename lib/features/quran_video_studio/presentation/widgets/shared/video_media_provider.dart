import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Platform-safe ImageProvider helper for custom image backgrounds across Web and Native.
ImageProvider getCustomImageProvider(String path) {
  if (kIsWeb ||
      path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('blob:')) {
    return NetworkImage(path);
  }
  return FileImage(File(path));
}
