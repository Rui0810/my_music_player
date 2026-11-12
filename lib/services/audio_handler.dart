import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer(
    // iOSの通知センター制御との干渉を避けるため、オフロードは無効のまま
    androidAudioOffloadPreferences: const AndroidAudioOffloadPreferences(
      audioOffloadMode: AndroidAudioOffloadMode.disabled,
    ),
  );

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _initSession();
  }

  Future<void> _initSession() async {
    final session = await AudioSession.instance;
    // iOSでバックグラウンド再生を許可する設定
    await session.configure(const AudioSessionConfiguration.music());
    // セッションをアクティブにする
    await session.setActive(true);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  Future<void> loadFile(String path, String title) async {
    try {
      // 再生前にセッションがアクティブであることを再確認
      final session = await AudioSession.instance;
      await session.setActive(true);

      await _player.stop();
      final duration = await _player.setFilePath(path);
      mediaItem.add(MediaItem(id: path, title: title, duration: duration));
      await _player.play();
    } catch (e) {
      print("Error loading file: $e");
    }
  }
}
