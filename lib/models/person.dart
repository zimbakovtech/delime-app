import 'package:flutter/material.dart';

/// A trip member.
@immutable
class Person {
  final String id;
  final String name;

  /// ARGB color value used for this person's avatar.
  final int colorValue;

  const Person({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  /// Up to two uppercase initials derived from the name.
  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Person copyWith({String? name, int? colorValue}) => Person(
        id: id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'color': colorValue,
      };

  factory Person.fromMap(Map<String, Object?> map) => Person(
        id: map['id'] as String,
        name: map['name'] as String,
        colorValue: map['color'] as int,
      );

  @override
  bool operator ==(Object other) => other is Person && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
