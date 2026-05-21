import 'package:flutter/material.dart';

class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor,
    required this.onTap,
  });
}
