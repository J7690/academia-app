import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Global provider for ShareMode used during screenshot-based sharing.
///
/// When [isShareModeEnabled] is true, shareable widgets can hide or
/// simplify parts of the UI (menus, buttons, animations) and display
/// the mandatory Academia signature.
class ShareModeProvider extends ChangeNotifier {
  bool _isShareModeEnabled = false;
  bool _isBusy = false;

  bool get isShareModeEnabled => _isShareModeEnabled;

  /// True while a share operation is running.
  bool get isBusy => _isBusy;

  /// Runs [action] with ShareMode enabled, then restores the previous state.
  ///
  /// This method waits for the end of the current frame so that widgets
  /// depending on [isShareModeEnabled] have a chance to rebuild before
  /// the screenshot is taken.
  Future<T> runWithShareMode<T>(Future<T> Function() action) async {
    if (_isBusy) {
      // Avoid re-entrancy: just run the action without touching the mode.
      return action();
    }

    _isBusy = true;
    _setShareMode(true);

    try {
      // Wait until the current frame is fully painted.
      await WidgetsBinding.instance.endOfFrame;
      return await action();
    } finally {
      _setShareMode(false);
      _isBusy = false;
    }
  }

  void _setShareMode(bool value) {
    if (_isShareModeEnabled == value) return;
    _isShareModeEnabled = value;
    notifyListeners();
  }
}
