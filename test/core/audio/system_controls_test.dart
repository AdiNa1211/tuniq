import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/core/audio/app_audio_handler.dart';
import 'package:tuniq/core/audio/interruptions.dart';
import 'package:tuniq/features/library/domain/song.dart';

import '../../helpers/fake_interruptions.dart';
import '../../helpers/fake_player_slot.dart';
import '../../helpers/fixtures.dart';

void main() {
  late FakePlayerSlot slot;
  late FakeInterruptions interruptions;
  late AppAudioHandler handler;
  final songs = testSongs.take(3).toList();

  setUp(() {
    slot = FakePlayerSlot();
    interruptions = FakeInterruptions();
    handler = AppAudioHandler(slot: slot, interruptions: interruptions);
  });

  tearDown(() => handler.dispose());

  Future<void> interrupt(AudioInterruption interruption) async {
    interruptions.emit(interruption);
    await pumpEventQueue();
  }

  group('interruptions', () {
    test('a call pauses and playback resumes after it', () async {
      await handler.playQueue(songs);
      await interrupt(AudioInterruption.pause);
      expect(slot.playing, isFalse);
      expect(handler.state.playing, isFalse);

      await interrupt(AudioInterruption.resume);
      expect(slot.playing, isTrue);
      expect(handler.state.playing, isTrue);
    });

    test('does not resume what was already paused', () async {
      await handler.playQueue(songs);
      await handler.pause();
      await interrupt(AudioInterruption.pause);
      await interrupt(AudioInterruption.resume);
      expect(slot.playing, isFalse);
    });

    test('pressing pause during a call keeps it paused afterwards', () async {
      await handler.playQueue(songs);
      await interrupt(AudioInterruption.pause);
      await handler.pause();
      await interrupt(AudioInterruption.resume);
      expect(slot.playing, isFalse);
    });

    test('an interruption that ends without resume stays paused', () async {
      await handler.playQueue(songs);
      await interrupt(AudioInterruption.pause);
      await interrupt(AudioInterruption.ended);
      await interrupt(AudioInterruption.resume);
      expect(slot.playing, isFalse);
    });

    test('unplugging headphones pauses for good', () async {
      await handler.playQueue(songs);
      await interrupt(AudioInterruption.becameNoisy);
      expect(slot.playing, isFalse);
      await interrupt(AudioInterruption.resume);
      expect(slot.playing, isFalse);
    });
  });

  group('AudioSessionInterruptions.interruptionFor', () {
    AudioInterruption? map(bool begin, AudioInterruptionType type) =>
        AudioSessionInterruptions.interruptionFor(AudioInterruptionEvent(begin, type));

    test('maps begin and end events', () {
      expect(map(true, AudioInterruptionType.pause), AudioInterruption.pause);
      expect(map(true, AudioInterruptionType.unknown), AudioInterruption.pause);
      expect(map(false, AudioInterruptionType.pause), AudioInterruption.resume);
      expect(map(false, AudioInterruptionType.unknown), AudioInterruption.ended);
    });

    test('leaves ducking to the system', () {
      expect(map(true, AudioInterruptionType.duck), isNull);
      expect(map(false, AudioInterruptionType.duck), isNull);
    });
  });

  group('system controls', () {
    test('a headset click toggles play and pause', () async {
      await handler.playQueue(songs);
      await handler.click();
      expect(slot.playing, isFalse);
      await handler.click();
      expect(slot.playing, isTrue);
    });

    test('headset next and previous buttons skip', () async {
      await handler.playQueue(songs);
      await handler.click(MediaButton.next);
      expect(handler.state.current!.song, songs[1]);
      await handler.click(MediaButton.previous);
      expect(handler.state.current!.song, songs[0]);
    });

    test('seeking updates the notification position', () async {
      await handler.playQueue(songs);
      await handler.seek(const Duration(seconds: 75));
      expect(handler.playbackState.value.updatePosition, const Duration(seconds: 75));
    });

    test('swiping the app away while paused stops playback', () async {
      await handler.playQueue(songs);
      await handler.pause();
      await handler.onTaskRemoved();
      expect(handler.playbackState.value.processingState, AudioProcessingState.idle);
    });

    test('swiping the app away while playing keeps playing', () async {
      await handler.playQueue(songs);
      await handler.onTaskRemoved();
      expect(slot.playing, isTrue);
    });

    test('dismissing the notification stops playback', () async {
      await handler.playQueue(songs);
      await handler.pause();
      await handler.onNotificationDeleted();
      expect(handler.playbackState.value.processingState, AudioProcessingState.idle);
    });
  });

  group('notification artwork', () {
    Song songWith(Uri uri) => Song(
          id: 'art',
          title: 'Art',
          artist: 'Artist',
          album: 'Album',
          albumId: 'al',
          uri: uri,
          duration: const Duration(minutes: 3),
        );

    test('MediaStore songs pass their content URI for the thumbnail', () async {
      final uri = Uri.parse('content://media/external/audio/media/42');
      await handler.playQueue([songWith(uri)]);
      final item = handler.mediaItem.value!;
      expect(item.artUri, uri);
      expect(item.extras, {'loadThumbnailUri': uri.toString()});
    });

    test('other songs have no artwork URI', () async {
      await handler.playQueue([songWith(Uri.parse('file:///music/a.mp3'))]);
      expect(handler.mediaItem.value!.artUri, isNull);
    });
  });
}
