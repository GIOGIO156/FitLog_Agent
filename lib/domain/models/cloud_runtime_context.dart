import 'package:flutter/foundation.dart';

class CloudRuntimeContext extends ChangeNotifier {
  String? _accountId;
  String? _deviceId;
  String? _sessionId;
  bool _deviceReplaced = false;

  String? get accountId => _accountId;
  String? get deviceId => _deviceId;
  String? get sessionId => _sessionId;
  bool get deviceReplaced => _deviceReplaced;

  bool get canUseOfficialCloud =>
      !_deviceReplaced &&
      (_accountId ?? '').isNotEmpty &&
      (_deviceId ?? '').isNotEmpty &&
      (_sessionId ?? '').isNotEmpty;

  void bind({
    required String accountId,
    required String deviceId,
    required String sessionId,
  }) {
    final changed =
        _accountId != accountId ||
        _deviceId != deviceId ||
        _sessionId != sessionId ||
        _deviceReplaced;
    _accountId = accountId;
    _deviceId = deviceId;
    _sessionId = sessionId;
    _deviceReplaced = false;
    if (changed) {
      notifyListeners();
    }
  }

  void clear() {
    final changed =
        _accountId != null ||
        _deviceId != null ||
        _sessionId != null ||
        _deviceReplaced;
    _accountId = null;
    _deviceId = null;
    _sessionId = null;
    _deviceReplaced = false;
    if (changed) {
      notifyListeners();
    }
  }

  void markDeviceReplaced() {
    if (_deviceReplaced) {
      return;
    }
    _deviceReplaced = true;
    notifyListeners();
  }
}
