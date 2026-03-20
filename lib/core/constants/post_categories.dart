import 'package:flutter/material.dart';

/// Product categories available when posting an item.
const List<String> postCategories = [
  'Books & Supplies',
  'Clothing & Accessories',
  'Electronics',
  'Food & Drinks',
  'Furniture',
  'Sports & Outdoors',
  'Tickets & Events',
  'Transportation',
  'Tutoring & Services',
  'Other',
];

/// Material icon associated with each category for the catalog quick-access strip.
const Map<String, IconData> categoryIcons = {
  'Books & Supplies': Icons.menu_book,
  'Clothing & Accessories': Icons.checkroom,
  'Electronics': Icons.devices,
  'Food & Drinks': Icons.fastfood,
  'Furniture': Icons.chair,
  'Sports & Outdoors': Icons.sports_soccer,
  'Tickets & Events': Icons.confirmation_number,
  'Transportation': Icons.directions_bike,
  'Tutoring & Services': Icons.school,
  'Other': Icons.category,
};
