import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'live_arena_service.dart';
import 'quiz_battle_service.dart';

/// Service pour la gamification des spectateurs Live Arena
class SpectatorGamificationService {
  static final Map<String, SpectatorProfile> _profiles = {};
  static final Map<String, List<Achievement>> _achievements = {};
  static final Map<String, List<LeaderboardEntry>> _leaderboards = {};
  
  /// Obtenir le profil d'un spectateur
  static Future<SpectatorProfile> getProfile(String userId) async {
    if (_profiles.containsKey(userId)) {
      return _profiles[userId]!;
    }
    
    try {
      // Charger depuis la base
      final result = await Supabase.instance.client
          .from('spectator_profiles')
          .select()
          .eq('user_id', userId)
          .single();
      
      final profile = SpectatorProfile.fromJson(result);
      _profiles[userId] = profile;
      return profile;
    } catch (e) {
      // Créer un nouveau profil
      final newProfile = SpectatorProfile.create(userId);
      await _saveProfile(newProfile);
      _profiles[userId] = newProfile;
      return newProfile;
    }
  }
  
  /// Mettre à jour le profil après une session
  static Future<void> updateProfile({
    required String userId,
    required String sessionId,
    required int supportActions,
    required int chatMessages,
    required int reactions,
    required Duration sessionDuration,
  }) async {
    final profile = await getProfile(userId);
    
    // Mettre à jour les statistiques
    profile.totalSessions++;
    profile.totalSupportActions += supportActions;
    profile.totalChatMessages += chatMessages;
    profile.totalReactions += reactions;
    profile.totalWatchTime += sessionDuration.inMinutes;
    
    // Calculer les points d'expérience
    final xpGained = _calculateXP(
      supportActions: supportActions,
      chatMessages: chatMessages,
      reactions: reactions,
      sessionDuration: sessionDuration,
    );
    profile.totalXP += xpGained;
    
    // Mettre à jour le niveau
    profile.level = _calculateLevel(profile.totalXP);
    profile.currentXP = profile.totalXP - _getXPRequiredForLevel(profile.level - 1);
    profile.nextLevelXP = _getXPRequiredForLevel(profile.level) - _getXPRequiredForLevel(profile.level - 1);
    
    // Mettre à jour les badges
    await _updateBadges(profile);
    
    // Sauvegarder
    await _saveProfile(profile);
    _profiles[userId] = profile;
    
    // Vérifier les achievements
    await _checkAchievements(userId, profile);
  }
  
  /// Supporter un fighter
  static Future<void> supportFighter({
    required String userId,
    required String sessionId,
    required String fighterId,
  }) async {
    // Appeler le service Live Arena
    await LiveArenaService.supportFighter(
      sessionId: sessionId,
      spectatorId: userId,
      fighterId: fighterId,
    );
    
    // Mettre à jour le profil
    final profile = await getProfile(userId);
    profile.totalSupportActions++;
    profile.totalXP += 5; // 5 XP par support
    
    // Mettre à jour le streak de support
    profile.currentSupportStreak++;
    if (profile.currentSupportStreak > profile.maxSupportStreak) {
      profile.maxSupportStreak = profile.currentSupportStreak;
    }
    
    await _saveProfile(profile);
    _profiles[userId] = profile;
  }
  
  /// Envoyer un message de chat
  static Future<void> sendChatMessage({
    required String userId,
    required String sessionId,
    required String message,
  }) async {
    // Appeler le service Live Arena
    await LiveArenaService.sendChatMessage(
      sessionId: sessionId,
      userId: userId,
      message: message,
      messageType: 'text',
    );
    
    // Mettre à jour le profil
    final profile = await getProfile(userId);
    profile.totalChatMessages++;
    profile.totalXP += 2; // 2 XP par message
    
    await _saveProfile(profile);
    _profiles[userId] = profile;
  }
  
  /// Envoyer une réaction
  static Future<void> sendReaction({
    required String userId,
    required String sessionId,
    required String reaction,
  }) async {
    // Appeler le service Live Arena
    await LiveArenaService.sendChatMessage(
      sessionId: sessionId,
      userId: userId,
      message: reaction,
      messageType: 'reaction',
    );
    
    // Mettre à jour le profil
    final profile = await getProfile(userId);
    profile.totalReactions++;
    profile.totalXP += 1; // 1 XP par réaction
    
    await _saveProfile(profile);
    _profiles[userId] = profile;
  }
  
  /// Obtenir les achievements d'un utilisateur
  static Future<List<Achievement>> getAchievements(String userId) async {
    if (_achievements.containsKey(userId)) {
      return _achievements[userId]!;
    }
    
    try {
      final result = await Supabase.instance.client
          .from('spectator_achievements')
          .select()
          .eq('user_id', userId)
          .order('unlocked_at', ascending: false);
      
      final achievements = result.map((json) => Achievement.fromJson(json)).toList();
      _achievements[userId] = achievements;
      return achievements;
    } catch (e) {
      return [];
    }
  }
  
  /// Obtenir le leaderboard
  static Future<List<LeaderboardEntry>> getLeaderboard({
    String period = 'weekly', // 'daily', 'weekly', 'monthly', 'all_time'
    int limit = 50,
  }) async {
    final cacheKey = '${period}_${limit}';
    
    if (_leaderboards.containsKey(cacheKey)) {
      return _leaderboards[cacheKey]!;
    }
    
    try {
      String orderBy;
      switch (period) {
        case 'daily':
          orderBy = 'daily_xp DESC';
          break;
        case 'weekly':
          orderBy = 'weekly_xp DESC';
          break;
        case 'monthly':
          orderBy = 'monthly_xp DESC';
          break;
        case 'all_time':
        default:
          orderBy = 'total_xp DESC';
          break;
      }
      
      final result = await Supabase.instance.client
          .from('spectator_profiles')
          .select('user_id, total_xp, level, $orderBy')
          .order(orderBy)
          .limit(limit);
      
      final leaderboard = result.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        return LeaderboardEntry(
          rank: index + 1,
          userId: data['user_id'],
          username: 'User ${data['user_id']?.toString().substring(0, 8)}', // Simplifié
          xp: data['total_xp'] ?? 0,
          level: data['level'] ?? 1,
        );
      }).toList();
      
      _leaderboards[cacheKey] = leaderboard;
      return leaderboard;
    } catch (e) {
      return [];
    }
  }
  
  /// Obtenir les badges disponibles
  static List<Badge> getAvailableBadges() {
    return [
      Badge(
        id: 'first_support',
        name: 'Premier Support',
        description: 'Supporter un fighter pour la première fois',
        icon: '👍',
        color: Colors.blue,
        requirement: BadgeRequirement(type: 'supports', value: 1),
      ),
      Badge(
        id: 'chat_starter',
        name: 'Initié du Chat',
        description: 'Envoyer 10 messages dans le chat',
        icon: '💬',
        color: Colors.green,
        requirement: BadgeRequirement(type: 'messages', value: 10),
      ),
      Badge(
        id: 'reaction_master',
        name: 'Maître des Réactions',
        description: 'Envoyer 50 réactions',
        icon: '😍',
        color: Colors.purple,
        requirement: BadgeRequirement(type: 'reactions', value: 50),
      ),
      Badge(
        id: 'dedicated_spectator',
        name: 'Spectateur Dédié',
        description: 'Regarder 10 sessions complètes',
        icon: '👁️',
        color: Colors.orange,
        requirement: BadgeRequirement(type: 'sessions', value: 10),
      ),
      Badge(
        id: 'support_streak_5',
        name: 'Support en Série',
        description: 'Supporter 5 fighters consécutivement',
        icon: '🏆',
        color: const Color(0xFFFFD700),
        requirement: BadgeRequirement(type: 'support_streak', value: 5),
      ),
      Badge(
        id: 'level_5',
        name: 'Spectateur Niveau 5',
        description: 'Atteindre le niveau 5',
        icon: '⭐',
        color: Colors.amber,
        requirement: BadgeRequirement(type: 'level', value: 5),
      ),
      Badge(
        id: 'level_10',
        name: 'Spectateur Niveau 10',
        description: 'Atteindre le niveau 10',
        icon: '🌟',
        color: Colors.amber,
        requirement: BadgeRequirement(type: 'level', value: 10),
      ),
      Badge(
        id: 'xp_1000',
        name: 'Millésime d\'XP',
        description: 'Gagner 1000 XP au total',
        icon: '🏆',
        color: const Color(0xFFFFD700),
        requirement: BadgeRequirement(type: 'total_xp', value: 1000),
      ),
    ];
  }
  
  /// Calculer les points d'expérience
  static int _calculateXP({
    required int supportActions,
    required int chatMessages,
    required int reactions,
    required Duration sessionDuration,
  }) {
    int xp = 0;
    
    // XP pour les actions
    xp += supportActions * 5;  // 5 XP par support
    xp += chatMessages * 2;   // 2 XP par message
    xp += reactions * 1;      // 1 XP par réaction
    
    // XP pour la durée de session
    final minutes = sessionDuration.inMinutes;
    if (minutes >= 30) {
      xp += 20; // Bonus pour longue session
    } else if (minutes >= 15) {
      xp += 10; // Bonus pour session moyenne
    } else if (minutes >= 5) {
      xp += 5;  // Bonus pour courte session
    }
    
    return xp;
  }
  
  /// Calculer le niveau basé sur l'XP
  static int _calculateLevel(int totalXP) {
    // Formule: Niveau = floor(sqrt(XP / 100)) + 1
    return (sqrt(totalXP / 100)).floor() + 1;
  }
  
  /// Obtenir l'XP requis pour un niveau
  static int _getXPRequiredForLevel(int level) {
    // Formule: XP = 100 * (niveau - 1)^2
    return 100 * (level - 1) * (level - 1);
  }
  
  /// Mettre à jour les badges
  static Future<void> _updateBadges(SpectatorProfile profile) async {
    final availableBadges = getAvailableBadges();
    final newBadges = <Badge>[];
    
    for (final badge in availableBadges) {
      if (profile.badges.contains(badge.id)) continue;
      
      bool unlocked = false;
      switch (badge.requirement.type) {
        case 'supports':
          unlocked = profile.totalSupportActions >= badge.requirement.value;
          break;
        case 'messages':
          unlocked = profile.totalChatMessages >= badge.requirement.value;
          break;
        case 'reactions':
          unlocked = profile.totalReactions >= badge.requirement.value;
          break;
        case 'sessions':
          unlocked = profile.totalSessions >= badge.requirement.value;
          break;
        case 'support_streak':
          unlocked = profile.maxSupportStreak >= badge.requirement.value;
          break;
        case 'level':
          unlocked = profile.level >= badge.requirement.value;
          break;
        case 'total_xp':
          unlocked = profile.totalXP >= badge.requirement.value;
          break;
      }
      
      if (unlocked) {
        profile.badges.add(badge.id);
        newBadges.add(badge);
        
        // Ajouter l'achievement
        await _unlockAchievement(profile.userId, badge);
      }
    }
  }
  
  /// Débloquer un achievement
  static Future<void> _unlockAchievement(String userId, Badge badge) async {
    try {
      await Supabase.instance.client
          .from('spectator_achievements')
          .insert({
            'user_id': userId,
            'badge_id': badge.id,
            'badge_name': badge.name,
            'badge_description': badge.description,
            'badge_icon': badge.icon,
            'badge_color': badge.color.value,
            'unlocked_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Erreur lors du déblocage d\'achievement: $e');
    }
  }
  
  /// Vérifier les achievements
  static Future<void> _checkAchievements(String userId, SpectatorProfile profile) async {
    // Charger les achievements existants
    await getAchievements(userId);
    
    // Vérifier les achievements spéciaux
    await _checkSpecialAchievements(userId, profile);
  }
  
  /// Vérifier les achievements spéciaux
  static Future<void> _checkSpecialAchievements(String userId, SpectatorProfile profile) async {
    // Achievement: Supporter 100 fighters
    if (profile.totalSupportActions >= 100 && !_hasAchievement(userId, 'super_supporter')) {
      await _unlockSpecialAchievement(userId, 'super_supporter', 'Super Supporter', 'Supporter 100 fighters', '🏆');
    }
    
    // Achievement: 1000 messages de chat
    if (profile.totalChatMessages >= 1000 && !_hasAchievement(userId, 'chat_master')) {
      await _unlockSpecialAchievement(userId, 'chat_master', 'Maître du Chat', 'Envoyer 1000 messages', '💬');
    }
    
    // Achievement: 10 heures de visionnage
    if (profile.totalWatchTime >= 600 && !_hasAchievement(userId, 'dedicated_watcher')) {
      await _unlockSpecialAchievement(userId, 'dedicated_watcher', 'Spectateur Dédié', 'Regarder 10 heures de battles', '👁️');
    }
    
    // Achievement: Niveau 20
    if (profile.level >= 20 && !_hasAchievement(userId, 'elite_spectator')) {
      await _unlockSpecialAchievement(userId, 'elite_spectator', 'Spectateur Élite', 'Atteindre le niveau 20', '⭐');
    }
  }
  
  /// Débloquer un achievement spécial
  static Future<void> _unlockSpecialAchievement(String userId, String id, String name, String description, String icon) async {
    try {
      await Supabase.instance.client
          .from('spectator_achievements')
          .insert({
            'user_id': userId,
            'badge_id': id,
            'badge_name': name,
            'badge_description': description,
            'badge_icon': icon,
            'badge_color': Colors.gold.value,
            'unlocked_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Erreur lors du déblocage d\'achievement spécial: $e');
    }
  }
  
  /// Vérifier si un utilisateur a un achievement
  static bool _hasAchievement(String userId, String badgeId) {
    final achievements = _achievements[userId] ?? [];
    return achievements.any((a) => a.badgeId == badgeId);
  }
  
  /// Sauvegarder le profil
  static Future<void> _saveProfile(SpectatorProfile profile) async {
    try {
      await Supabase.instance.client
          .from('spectator_profiles')
          .upsert(profile.toJson(), onConflict: 'user_id');
    } catch (e) {
      print('Erreur lors de la sauvegarde du profil: $e');
    }
  }
}

/// Profil de spectateur
class SpectatorProfile {
  final String userId;
  int level;
  int totalXP;
  int currentXP;
  int nextLevelXP;
  int totalSessions;
  int totalSupportActions;
  int totalChatMessages;
  int totalReactions;
  int totalWatchTime;
  int currentSupportStreak;
  int maxSupportStreak;
  List<String> badges;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  SpectatorProfile({
    required this.userId,
    required this.level,
    required this.totalXP,
    required this.currentXP,
    required this.nextLevelXP,
    required this.totalSessions,
    required this.totalSupportActions,
    required this.totalChatMessages,
    required this.totalReactions,
    required this.totalWatchTime,
    required this.currentSupportStreak,
    required this.maxSupportStreak,
    required this.badges,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory SpectatorProfile.create(String userId) {
    final now = DateTime.now();
    return SpectatorProfile(
      userId: userId,
      level: 1,
      totalXP: 0,
      currentXP: 0,
      nextLevelXP: 100,
      totalSessions: 0,
      totalSupportActions: 0,
      totalChatMessages: 0,
      totalReactions: 0,
      totalWatchTime: 0,
      currentSupportStreak: 0,
      maxSupportStreak: 0,
      badges: [],
      createdAt: now,
      updatedAt: now,
    );
  }
  
  factory SpectatorProfile.fromJson(Map<String, dynamic> json) {
    return SpectatorProfile(
      userId: json['user_id'],
      level: json['level'] ?? 1,
      totalXP: json['total_xp'] ?? 0,
      currentXP: json['current_xp'] ?? 0,
      nextLevelXP: json['next_level_xp'] ?? 100,
      totalSessions: json['total_sessions'] ?? 0,
      totalSupportActions: json['total_support_actions'] ?? 0,
      totalChatMessages: json['total_chat_messages'] ?? 0,
      totalReactions: json['total_reactions'] ?? 0,
      totalWatchTime: json['total_watch_time'] ?? 0,
      currentSupportStreak: json['current_support_streak'] ?? 0,
      maxSupportStreak: json['max_support_streak'] ?? 0,
      badges: List<String>.from(json['badges'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'level': level,
      'total_xp': totalXP,
      'current_xp': currentXP,
      'next_level_xp': nextLevelXP,
      'total_sessions': totalSessions,
      'total_support_actions': totalSupportActions,
      'total_chat_messages': totalChatMessages,
      'total_reactions': totalReactions,
      'total_watch_time': totalWatchTime,
      'current_support_streak': currentSupportStreak,
      'max_support_streak': maxSupportStreak,
      'badges': badges,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Badge
class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final Color color;
  final BadgeRequirement requirement;
  
  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.requirement,
  });
}

/// Exigence de badge
class BadgeRequirement {
  final String type;
  final int value;
  
  BadgeRequirement({
    required this.type,
    required this.value,
  });
}

/// Achievement
class Achievement {
  final String id;
  final String userId;
  final String badgeId;
  final String badgeName;
  final String badgeDescription;
  final String badgeIcon;
  final String badgeColor;
  final DateTime unlockedAt;
  
  Achievement({
    required this.id,
    required this.userId,
    required this.badgeId,
    required this.badgeName,
    required this.badgeDescription,
    required this.badgeIcon,
    required this.badgeColor,
    required this.unlockedAt,
  });
  
  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      userId: json['user_id'],
      badgeId: json['badge_id'],
      badgeName: json['badge_name'],
      badgeDescription: json['badge_description'],
      badgeIcon: json['badge_icon'],
      badgeColor: json['badge_color'],
      unlockedAt: DateTime.parse(json['unlocked_at']),
    );
  }
}

/// Entrée du leaderboard
class LeaderboardEntry {
  final int rank;
  final String userId;
  final String username;
  final int xp;
  final int level;
  
  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.xp,
    required this.level,
  });
}
