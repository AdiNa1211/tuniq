import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:tuniq/spike/crossfade_spike_page.dart';
import 'package:tuniq/spike/device_library_spike_page.dart';

// Phase 1 throwaway spikes, kept until the iOS library check passes.
// Run with: flutter run -t lib/spike/main_spike.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  runApp(const SpikeApp());
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tuniq spikes',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: const _SpikeHome(),
    );
  }
}

class _SpikeHome extends StatefulWidget {
  const _SpikeHome();

  @override
  State<_SpikeHome> createState() => _SpikeHomeState();
}

class _SpikeHomeState extends State<_SpikeHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phase 1 spikes')),
      // IndexedStack keeps both pages (and their players) alive across tabs.
      body: IndexedStack(
        index: _tab,
        children: const [CrossfadeSpikePage(), DeviceLibrarySpikePage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Crossfade'),
          NavigationDestination(
            icon: Icon(Icons.library_music),
            label: 'Device library',
          ),
        ],
      ),
    );
  }
}
