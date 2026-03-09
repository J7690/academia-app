import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Widget réutilisable pour afficher l'avatar d'un utilisateur.
/// Affiche la photo de profil si `imageUrl` est fourni,
/// sinon affiche l'initiale du nom sur un fond coloré.
///
/// Supporte un indicateur de présence en ligne (cercle vert).
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final bool showOnlineIndicator;
  final bool isOnline;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 20,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.borderColor,
    this.borderWidth = 0,
  });

  static Color getColorForName(String name) {
    if (name.isEmpty) return Colors.grey;
    const colors = [
      Color(0xFF00897B), // Teal
      Color(0xFF5C6BC0), // Indigo
      Color(0xFFE53935), // Red
      Color(0xFF8E24AA), // Purple
      Color(0xFFFB8C00), // Orange
      Color(0xFF00ACC1), // Cyan
      Color(0xFFD81B60), // Pink
      Color(0xFF1E88E5), // Blue
      Color(0xFF43A047), // Green
      Color(0xFF6D4C41), // Brown
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final bgColor = getColorForName(name);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final diameter = radius * 2;

    Widget avatar;
    if (hasImage) {
      avatar = CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: radius * 0.8,
            ),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: radius * 0.8,
            ),
          ),
        ),
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: radius * 0.8,
          ),
        ),
      );
    }

    // Wrap with border if needed
    if (borderColor != null && borderWidth > 0) {
      avatar = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: borderWidth),
        ),
        child: avatar,
      );
    }

    // Add online indicator
    if (showOnlineIndicator) {
      final dotSize = radius * 0.45;
      return SizedBox(
        width: diameter + (borderWidth * 2),
        height: diameter + (borderWidth * 2),
        child: Stack(
          children: [
            avatar,
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return avatar;
  }
}
