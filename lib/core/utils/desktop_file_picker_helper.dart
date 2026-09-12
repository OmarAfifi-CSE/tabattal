import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

/// Helper utility to reliably display native file pickers on Desktop,
/// with a robust fallback on Windows that avoids COM apartment state
/// conflicts (RPC_E_WRONG_THREAD 0x8001010E).
class DesktopFilePickerHelper {
  const DesktopFilePickerHelper._();

  static Future<String?> pickFileWindows({
    required String filter,
    required String title,
  }) async {
    if (kIsWeb || !Platform.isWindows) return null;

    try {
      final script = '''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.OpenFileDialog
\$dialog.Filter = "$filter"
\$dialog.Title = "$title"
\$dialog.RestoreDirectory = \$true
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  [Console]::Out.Write(\$dialog.FileName)
}
''';

      // stdoutEncoding UTF-8 must match the script's OutputEncoding above,
      // otherwise non-Latin filenames (e.g. Arabic) come back garbled and
      // the existsSync check below would wrongly reject them.
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Sta',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      // Restore Windows OS focus to the Flutter window immediately
      try {
        await windowManager.focus();
      } catch (_) {}

      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty && File(path).existsSync()) {
          return p.normalize(path);
        }
      } else {
        debugPrint('DesktopFilePickerHelper error: ${result.stderr}');
      }
    } catch (e) {
      debugPrint('DesktopFilePickerHelper exception: $e');
    }
    return null;
  }
}
