import 'package:flutter/material.dart';

import '../../export/file_share_service.dart';

import '../diagnostics/auth_diagnostics.dart';
import '../localization/localization_extensions.dart';
import 'fitlog_notifications.dart';

class AuthDiagnosticsExportButton extends StatefulWidget {
  const AuthDiagnosticsExportButton({super.key});

  @override
  State<AuthDiagnosticsExportButton> createState() =>
      _AuthDiagnosticsExportButtonState();
}

class _AuthDiagnosticsExportButtonState
    extends State<AuthDiagnosticsExportButton> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final filePath = await AuthDiagnostics.instance.exportFile();
      if (!mounted) return;
      final shared = await FileShareService.shareFile(
        filePath,
        origin: FileShareService.originFor(context),
      );
      if (mounted && !shared) {
        FitLogNotifications.error(
          context,
          context.stringsRead.exportShareFailed,
        );
      }
    } catch (_) {
      if (mounted) {
        FitLogNotifications.error(
          context,
          context.stringsRead.authDiagnosticsExportFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('export_auth_diagnostics'),
    onPressed: _exporting ? null : _export,
    icon: const Icon(Icons.file_download_outlined, size: 18),
    label: Text(context.strings.exportAuthDiagnostics),
  );
}
