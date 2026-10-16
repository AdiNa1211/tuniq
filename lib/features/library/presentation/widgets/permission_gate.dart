import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tuniq/features/library/domain/library_permission.dart';

/// Explains why music access is needed and offers the right next step.
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    required this.permission,
    required this.onAllow,
    required this.onOpenSettings,
    super.key,
  });

  final LibraryPermission permission;
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocked = permission == LibraryPermission.permanentlyDenied;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final reason = isIOS
        ? 'Tuniq plays the songs downloaded to your Music library.'
        : 'Tuniq plays the music files stored on your phone.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Let Tuniq find your music',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '$reason Nothing leaves your phone.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (blocked) ...[
              FilledButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
              ),
              const SizedBox(height: 12),
              Text(
                'Music access is turned off. Turn it on in Settings, then come back.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ] else
              FilledButton(onPressed: onAllow, child: const Text('Allow access')),
          ],
        ),
      ),
    );
  }
}
