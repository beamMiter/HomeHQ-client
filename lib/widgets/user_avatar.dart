import 'package:flutter/material.dart';

import '../shared/app_colors.dart';

/// Up to two letters standing for [name]: the first letter of the first and
/// last words ("Somchai Jaidee" → "SJ"), or of the only word. Empty when there
/// is no name.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '';
  String first(String w) => String.fromCharCodes(w.runes.take(1)).toUpperCase();
  return words.length == 1
      ? first(words.first)
      : first(words.first) + first(words.last);
}

/// A round avatar with the user's initials (a person icon when there is no
/// name). [onDark] gives it a light ring for the dark Home header.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.onDark = false,
  });

  final String name;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final letters = initialsOf(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A78FF), AppColors.softBlue],
        ),
        border: onDark
            ? Border.all(color: Colors.white.withValues(alpha: .7), width: 2)
            : null,
      ),
      child: letters.isEmpty
          ? Icon(Icons.person_rounded, size: size * .55, color: Colors.white)
          : Text(
              letters,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * .38,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
              ),
            ),
    );
  }
}
