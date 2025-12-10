import 'package:flutter/foundation.dart';

class StudentDashboardNavController {
  StudentDashboardNavController._();

  static final ValueNotifier<int> _indexNotifier = ValueNotifier<int>(0);

  static ValueNotifier<int> get indexNotifier => _indexNotifier;

  static int get currentIndex => _indexNotifier.value;

  static void setIndex(int index) {
    if (index == _indexNotifier.value) return;
    _indexNotifier.value = index;
  }
}
