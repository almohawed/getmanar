import 'package:flutter/material.dart';

class DashboardPalette {
  static LinearGradient headerGradient(String id) {
    final colors = _pair(id);
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static LinearGradient bannerGradient(String id) {
    final colors = _pair(id);
    return LinearGradient(
      colors: colors,
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
    );
  }

  static List<Color> _pair(String id) {
    switch (id) {
      case 'admin':
        return [Colors.indigo.shade900, Colors.blue.shade600];
      case 'deputyAcademic':
        return [Colors.deepPurple.shade800, Colors.indigo.shade600];
      case 'deputySchool':
        return [Colors.teal.shade800, Colors.green.shade600];
      case 'deputyStudent':
        return [Colors.orange.shade800, Colors.amber.shade600];
      case 'teacher':
        return [Colors.blue.shade800, Colors.blue.shade500];
      case 'parent':
        return [Colors.green.shade800, Colors.teal.shade500];
      case 'counselor':
        return [Colors.purple.shade800, Colors.teal.shade500];
      case 'administrative':
        return [Colors.blueGrey.shade800, Colors.blueGrey.shade500];
      default:
        return [Colors.indigo.shade800, Colors.indigo.shade500];
    }
  }
}
