import 'package:flutter/material.dart';

/// Placeholder; search over the real library arrives in Phase 3.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TextField(
            enabled: false,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Songs, artists, albums',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 48),
          Icon(Icons.manage_search, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Search arrives with your real library in Phase 3.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
