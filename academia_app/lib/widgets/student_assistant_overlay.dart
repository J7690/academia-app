import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/student_weather_provider.dart';
import '../providers/student_announcements_provider.dart';
import '../providers/student_academic_calendar_provider.dart';

/// A floating notification overlay that cycles through assistant messages
/// (weather, announcements, calendar) with slide-in/out animations.
/// Designed to work globally across all student tabs.
class StudentAssistantOverlay extends StatefulWidget {
  const StudentAssistantOverlay({super.key});

  @override
  State<StudentAssistantOverlay> createState() =>
      _StudentAssistantOverlayState();
}

class _StudentAssistantOverlayState extends State<StudentAssistantOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  Timer? _cycleTimer;
  Timer? _dismissTimer;
  int _currentMessageIndex = 0;
  bool _dismissed = false;
  bool _visible = false;

  static const Duration _showDuration = Duration(seconds: 6);
  static const Duration _pauseDuration = Duration(seconds: 18);
  static const Duration _animDuration = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: _animDuration,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    // Start the first notification after a short delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_dismissed) _showNext();
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  List<_AssistantMessage> _buildMessages(BuildContext context) {
    final messages = <_AssistantMessage>[];

    // Weather
    try {
      final weatherProvider = context.read<StudentWeatherProvider>();
      final weather = weatherProvider.weather;
      if (weather is Map<String, dynamic>) {
        final dynamic tempRaw = weather['temperature'];
        final dynamic codeRaw = weather['weatherCode'];
        final double? temp = tempRaw is num
            ? tempRaw.toDouble()
            : double.tryParse(tempRaw?.toString() ?? '');
        final int? code = codeRaw is num
            ? codeRaw.toInt()
            : int.tryParse(codeRaw?.toString() ?? '');
        final String city =
            weatherProvider.location?['city']?.toString() ?? '';

        if (temp != null) {
          final int rounded = temp.round();
          String desc = '';
          if (code != null) desc = _describeWeatherCode(code);
          String line = '$rounded°C';
          if (desc.isNotEmpty) line += ', $desc';
          if (city.isNotEmpty) line += ' · $city';

          IconData icon = Icons.wb_sunny_outlined;
          Color color = const Color(0xFFF59E0B);
          if (code != null) {
            icon = _iconForWeatherCode(code);
            color = _colorForWeatherCode(code);
          }

          messages.add(_AssistantMessage(
            icon: icon,
            iconColor: color,
            text: line,
            bgColor: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFDE68A),
          ));
        }
      }
    } catch (_) {}

    // Announcements
    try {
      final announcementsProvider =
          context.read<StudentAnnouncementsProvider>();
      final unread = announcementsProvider.unreadCount;
      if (unread > 0) {
        messages.add(_AssistantMessage(
          icon: Icons.campaign_outlined,
          iconColor: const Color(0xFF2563EB),
          text:
              '$unread annonce${unread > 1 ? 's' : ''} importante${unread > 1 ? 's' : ''} à lire',
          bgColor: const Color(0xFFEFF6FF),
          borderColor: const Color(0xFFBFDBFE),
        ));
      } else if (announcementsProvider.announcements.isNotEmpty) {
        final first = announcementsProvider.announcements.first;
        final title = first['title']?.toString() ?? '';
        if (title.isNotEmpty) {
          messages.add(_AssistantMessage(
            icon: Icons.campaign_outlined,
            iconColor: const Color(0xFF2563EB),
            text: title,
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFBFDBFE),
          ));
        }
      }
    } catch (_) {}

    // Calendar
    try {
      final calendarProvider =
          context.read<StudentAcademicCalendarProvider>();
      final upcoming = calendarProvider.upcomingFollowedCount;
      if (upcoming > 0) {
        messages.add(_AssistantMessage(
          icon: Icons.event_outlined,
          iconColor: const Color(0xFF16A34A),
          text:
              '$upcoming événement${upcoming > 1 ? 's' : ''} académique${upcoming > 1 ? 's' : ''} à venir',
          bgColor: const Color(0xFFF0FDF4),
          borderColor: const Color(0xFFBBF7D0),
        ));
      } else if (calendarProvider.events.isNotEmpty) {
        final first = calendarProvider.events.first;
        final title = first['title']?.toString() ?? '';
        if (title.isNotEmpty) {
          messages.add(_AssistantMessage(
            icon: Icons.event_outlined,
            iconColor: const Color(0xFF16A34A),
            text: title,
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFBBF7D0),
          ));
        }
      }
    } catch (_) {}

    return messages;
  }

  void _showNext() {
    if (!mounted || _dismissed) return;

    final messages = _buildMessages(context);
    if (messages.isEmpty) {
      // Retry later
      _cycleTimer = Timer(_pauseDuration, () {
        if (mounted && !_dismissed) _showNext();
      });
      return;
    }

    _currentMessageIndex = _currentMessageIndex % messages.length;
    setState(() => _visible = true);
    _animController.forward();

    // Auto-dismiss after _showDuration
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_showDuration, () {
      _hideAndScheduleNext();
    });
  }

  void _hideAndScheduleNext() {
    if (!mounted) return;
    _animController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _visible = false);
      _currentMessageIndex++;
      // Schedule next notification
      _cycleTimer?.cancel();
      _cycleTimer = Timer(_pauseDuration, () {
        if (mounted && !_dismissed) _showNext();
      });
    });
  }

  void _onDismissSwipe() {
    _dismissTimer?.cancel();
    _hideAndScheduleNext();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible && !_animController.isAnimating) {
      return const SizedBox.shrink();
    }

    final messages = _buildMessages(context);
    if (messages.isEmpty) return const SizedBox.shrink();

    final idx = _currentMessageIndex % messages.length;
    final msg = messages[idx];
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 4,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -100) {
                _onDismissSwipe();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: msg.bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: msg.borderColor, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(msg.icon, size: 20, color: msg.iconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        msg.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _onDismissSwipe,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Weather helpers (same as _MobileAssistantSection) ──────────

  static String _describeWeatherCode(int code) {
    if (code == 0) return 'Ciel dégagé';
    if (code <= 3) return 'Partiellement nuageux';
    if (code <= 49) return 'Brouillard';
    if (code <= 59) return 'Bruine';
    if (code <= 69) return 'Pluie';
    if (code <= 79) return 'Neige';
    if (code <= 84) return 'Averses';
    if (code <= 94) return 'Neige / grêle';
    return 'Orage';
  }

  static IconData _iconForWeatherCode(int code) {
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code <= 3) return Icons.cloud_outlined;
    if (code <= 49) return Icons.foggy;
    if (code <= 69) return Icons.grain;
    if (code <= 79) return Icons.ac_unit;
    if (code <= 84) return Icons.umbrella_outlined;
    return Icons.thunderstorm_outlined;
  }

  static Color _colorForWeatherCode(int code) {
    if (code == 0) return const Color(0xFFF59E0B);
    if (code <= 3) return const Color(0xFF6B7280);
    if (code <= 49) return const Color(0xFF9CA3AF);
    if (code <= 69) return const Color(0xFF3B82F6);
    if (code <= 79) return const Color(0xFF60A5FA);
    if (code <= 84) return const Color(0xFF2563EB);
    return const Color(0xFF7C3AED);
  }
}

class _AssistantMessage {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color bgColor;
  final Color borderColor;

  const _AssistantMessage({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.bgColor,
    required this.borderColor,
  });
}
