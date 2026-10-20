import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

class FileShareService {
  static Rect originFor(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize && !box.size.isEmpty) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(Offset.zero),
      width: 1,
      height: 1,
    );
  }

  /// Cancellation is normal. Completion does not confirm delivery by another app.
  /// Files remain available if the user cancels or the share sheet fails to open.
  static Future<bool> shareFile(String filePath, {required Rect origin}) async {
    final mimeType = switch (path.extension(filePath).toLowerCase()) {
      '.json' => 'application/json',
      '.xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, mimeType: mimeType)],
          title: path.basename(filePath),
          sharePositionOrigin: origin,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
