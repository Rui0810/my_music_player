import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer(
    androidAudioOffloadPreferences: const AndroidAudioOffloadPreferences(
      audioOffloadMode: AndroidAudioOffloadMode.disabled,
    ),
  );

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
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
      // オーディオセッションを音楽向けに設定
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // 1. 前の曲を確実に停止
      await _player.stop();
      
      // 2. 新しいファイルを読み込む
      final duration = await _player.setFilePath(path);
      
      // 3. 読み込み完了後に通知を更新
      mediaItem.add(MediaItem(
        id: path,
        title: title,
        duration: duration,
      ));
      
      // 4. 再生
      await _player.play();
    } catch (e) {
      print("Error loading file: $e");
    }
  }
}
