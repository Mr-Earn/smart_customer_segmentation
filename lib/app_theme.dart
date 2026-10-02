import 'package:flutter/material.dart';

const ink = Color(0xFF1C2823);
const forest = Color(0xFF183A32);
const lime = Color(0xFFC7F36B);
const canvas = Color(0xFFF2F4EF);
const muted = Color(0xFF77837C);
const mint = Color(0xFF74C9A4);
const coral = Color(0xFFF29472);
const sky = Color(0xFF71B6D1);

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: forest,
    surface: canvas,
    primary: forest,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: ink),
    bodySmall: TextStyle(color: muted),
  ),
);
