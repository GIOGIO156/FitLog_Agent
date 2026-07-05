import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../food/food_image_picker.dart';

class AiChatImageRecoveryDraft {
  const AiChatImageRecoveryDraft({
    required this.messageText,
    required this.provider,
    this.wasReadyVisual = false,
  });

  final String messageText;
  final String provider;
  final bool wasReadyVisual;
}

class RecoveredAiChatImages {
  const RecoveredAiChatImages({
    required this.messageText,
    required this.provider,
    required this.images,
    this.wasReadyVisual = false,
  });

  final String messageText;
  final String provider;
  final List<PickedFoodImage> images;
  final bool wasReadyVisual;
}

class AiChatImageRecoveryStore {
  const AiChatImageRecoveryStore._();

  static const String _pendingKey = 'fitlog.ai_chat_image.pending';
  static const String _messageTextKey = 'fitlog.ai_chat_image.message_text';
  static const String _providerKey = 'fitlog.ai_chat_image.provider';
  static const String _wasReadyVisualKey =
      'fitlog.ai_chat_image.was_ready_visual';

  static Future<void> savePending({
    required String messageText,
    required String provider,
    bool wasReadyVisual = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, true);
    await prefs.setString(_messageTextKey, messageText);
    await prefs.setString(_providerKey, provider);
    await prefs.setBool(_wasReadyVisualKey, wasReadyVisual);
  }

  static Future<AiChatImageRecoveryDraft?> loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_pendingKey) != true) {
      return null;
    }
    return AiChatImageRecoveryDraft(
      messageText: prefs.getString(_messageTextKey) ?? '',
      provider: prefs.getString(_providerKey) ?? '',
      wasReadyVisual: prefs.getBool(_wasReadyVisualKey) ?? false,
    );
  }

  static Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
    await prefs.remove(_messageTextKey);
    await prefs.remove(_providerKey);
    await prefs.remove(_wasReadyVisualKey);
  }
}

class AiChatImageRecoveryController extends ChangeNotifier {
  int _version = 0;
  RecoveredAiChatImages? _pending;

  int get version => _version;
  RecoveredAiChatImages? get pending => _pending;

  void restore(RecoveredAiChatImages draft) {
    _version += 1;
    _pending = draft;
    notifyListeners();
  }

  RecoveredAiChatImages? consume(int version) {
    if (version != _version) {
      return null;
    }
    final pending = _pending;
    _pending = null;
    return pending;
  }
}
