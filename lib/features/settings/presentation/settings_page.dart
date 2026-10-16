import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/core/audio/crossfade.dart';
import 'package:tuniq/features/settings/presentation/cubit/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: BlocSelector<SettingsCubit, SettingsState, ThemeMode>(
              selector: (state) => state.themeMode,
              builder: (context, themeMode) => SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (selection) =>
                    context.read<SettingsCubit>().setThemeMode(selection.first),
              ),
            ),
          ),
          const _SectionHeader('Playback'),
          const _CrossfadeSetting(),
        ],
      ),
    );
  }
}

class _CrossfadeSetting extends StatelessWidget {
  const _CrossfadeSetting();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return BlocSelector<SettingsCubit, SettingsState, CrossfadeSettings>(
      selector: (state) => state.crossfade,
      builder: (context, crossfade) => Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.swap_horiz),
            title: const Text('Crossfade'),
            subtitle: const Text('Blend the end of each song into the next'),
            value: crossfade.enabled,
            onChanged: cubit.setCrossfadeEnabled,
          ),
          if (crossfade.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Slider(
                      value: crossfade.seconds.toDouble(),
                      min: CrossfadeSettings.minSeconds.toDouble(),
                      max: CrossfadeSettings.maxSeconds.toDouble(),
                      divisions: CrossfadeSettings.maxSeconds - CrossfadeSettings.minSeconds,
                      label: '${crossfade.seconds} s',
                      semanticFormatterCallback: (value) => '${value.round()} seconds',
                      onChanged: (value) => cubit.setCrossfadeSeconds(value.round()),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${crossfade.seconds} s',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}
