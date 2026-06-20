import 'package:delime/models/person.dart';
import 'package:flutter/material.dart';

/// Colour-coded circular avatar showing a person's initials.
class PersonAvatar extends StatelessWidget {
  final Person person;
  final double size;

  const PersonAvatar({super.key, required this.person, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final color = person.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.28)!],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        person.initials,
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.82),
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// A small overlapping stack of avatars (used in purchase list rows).
class AvatarCluster extends StatelessWidget {
  final List<Person> people;
  final double size;
  final int max;

  const AvatarCluster({
    super.key,
    required this.people,
    this.size = 28,
    this.max = 4,
  });

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    final overflow = people.length - shown.length;
    final overlap = size * 0.38;
    final width = shown.isEmpty
        ? 0.0
        : size +
              (shown.length - 1) * (size - overlap) +
              (overflow > 0 ? (size - overlap) : 0);

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: _ring(context, PersonAvatar(person: shown[i], size: size)),
            ),
          if (overflow > 0)
            Positioned(
              left: shown.length * (size - overlap),
              child: _ring(
                context,
                Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2A313C),
                  ),
                  child: Text(
                    '+$overflow',
                    style: TextStyle(
                      fontSize: size * 0.34,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ring(BuildContext context, Widget child) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
      child: child,
    );
  }
}
