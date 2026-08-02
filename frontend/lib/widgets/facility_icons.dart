import 'package:flutter/material.dart';

/// icon_key -> (Flutter icon, display label for the admin picker).
/// Keep this the single source of truth for facility icons - both the
/// member-facing booking list and the admin facility form read from here.
const Map<String, ({IconData icon, String label})> kFacilityIcons = {
  'church': (icon: Icons.church, label: "예배/모임 공간"),
  'coffee': (icon: Icons.coffee, label: "카페/식당"),
  'groups': (icon: Icons.groups, label: "소모임"),
  'meeting_room': (icon: Icons.meeting_room, label: "회의실"),
  'sports': (icon: Icons.sports_basketball, label: "체육관"),
  'parking': (icon: Icons.local_parking, label: "주차장"),
  'library': (icon: Icons.menu_book, label: "도서실"),
};

IconData facilityIconFor(String? key) => kFacilityIcons[key]?.icon ?? Icons.church;
