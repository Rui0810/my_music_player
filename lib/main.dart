import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'models/track.dart';
import 'services/audio_handler.dart';

late MyAudioHandler audioHandler;

enum SortType { name, added }

Future<void> main() async {
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.music',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura Music',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF1E293B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            color: Colors.white,
          ),
        ),
      ),
      home: const PlayerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final List<Track> _tracks = [];
  SortType sortType = SortType.name;

  @override
  void initState() {
    super.initState();
    _loadSavedTracks();
  }

  Future<void> _loadSavedTracks() async {
    final docs = await getApplicationDocumentsDirectory();
    final dirsToScan = [
      Directory(docs.path),
      Directory('${docs.path}/Media'),
    ];

    final loadedTracks = <Track>[];
    for (final dir in dirsToScan) {
      if (await dir.exists()) {
        final files = dir.listSync();
        for (final file in files) {
          if (file is File) {
            final lowerPath = file.path.toLowerCase();
            if (lowerPath.endsWith('.mp3') ||
                lowerPath.endsWith('.m4a') ||
                lowerPath.endsWith('.wav') ||
                lowerPath.endsWith('.ogg') ||
                lowerPath.endsWith('.aac')) {
              if (!loadedTracks.any((t) => t.file.path == file.path)) {
                loadedTracks.add(Track(
                  title: file.uri.pathSegments.last,
                  file: file,
                ));
              }
            }
          }
        }
      }
    }

    setState(() {
      _tracks.clear();
      _tracks.addAll(loadedTracks);
      _sortTracks();
    });
  }

  void _sortTracks() {
    setState(() {
      if (sortType == SortType.name) {
        _tracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      } else if (sortType == SortType.added) {
        _tracks.sort((a, b) {
          final aMod = a.file.statSync().modified;
          final bMod = b.file.statSync().modified;
          return bMod.compareTo(aMod);
        });
      }
    });
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    if (result == null) return;

    final docs = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${docs.path}/Media');
    await mediaDir.create(recursive: true);

    for (final f in result) {
      if (f.path == null) continue;
      final src = File(f.path!);
      final dest = File('${mediaDir.path}/${f.name}');
      
      if (await dest.exists()) continue;

      await src.copy(dest.path);
      _tracks.add(Track(title: f.name, file: dest));
    }
    _sortTracks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('AURA MUSIC'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 💡 状態をストリーム監視して連動させる
                StreamBuilder<bool>(
                  stream: audioHandler.shuffleModeEnabledStream,
                  initialData: false,
                  builder: (context, snapshot) {
                    final isShuffle = snapshot.data ?? false;
                    return IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        color: isShuffle ? const Color(0xFF38BDF8) : Colors.grey,
                      ),
                      onPressed: () {
                        audioHandler.setShuffleMode(
                          isShuffle ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all
                        );
                      },
                    );
                  }
                ),
                StreamBuilder<LoopMode>(
                  stream: audioHandler.loopModeStream,
                  initialData: LoopMode.off,
                  builder: (context, snapshot) {
                    final loop = snapshot.data ?? LoopMode.off;
                    return IconButton(
                      icon: Icon(
                        loop == LoopMode.off
                            ? Icons.repeat
                            : loop == LoopMode.all
                                ? Icons.repeat_on
                                : Icons.repeat_one_on,
                        color: loop != LoopMode.off ? const Color(0xFF38BDF8) : Colors.grey,
                      ),
                      onPressed: () {
                        if (loop == LoopMode.off) {
                          audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
                        } else if (loop == LoopMode.all) {
                          audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
                        } else {
                          audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
                        }
                      },
                    );
                  }
                ),
                PopupMenuButton<SortType>(
                  icon: const Icon(Icons.sort, color: Colors.grey),
                  onSelected: (type) {
                    setState(() {
                      sortType = type;
                      _sortTracks();
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: SortType.name, child: Text('曲名順 (A-Z)')),
                    const PopupMenuItem(value: SortType.added, child: Text('追加日順 (新しい順)')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          ),
        ),
        child: StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, mediaItemSnapshot) {
            final currentMediaItem = mediaItemSnapshot.data;
            
            return ListView.builder(
              padding: const EdgeInsets.only(top: 120, bottom: 140, left: 16, right: 16),
              itemCount: _tracks.length,
              itemBuilder: (_, i) {
                final track = _tracks[i];
                final isPlaying = currentMediaItem?.id == track.file.path;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isPlaying ? const Color(0xFF1E293B) : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPlaying ? const Color(0xFF38BDF8).withOpacity(0.5) : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: isPlaying ? [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ] : [],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPlaying 
                            ? [const Color(0xFF38BDF8), const Color(0xFF818CF8)]
                            : [Colors.grey[800]!, Colors.grey[900]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPlaying ? Icons.graphic_eq : Icons.music_note,
                        color: isPlaying ? Colors.white : Colors.grey[400],
                        size: 28,
                      ),
                    ),
                    title: Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isPlaying ? FontWeight.w800 : FontWeight.w500,
                        color: isPlaying ? Colors.white : Colors.grey[300],
                        height: 1.3,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        isPlaying ? 'NOW PLAYING' : 'LOCAL FILE',
                        style: TextStyle(
                          color: isPlaying ? const Color(0xFF38BDF8) : Colors.grey[600],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    onTap: () => audioHandler.loadPlaylist(_tracks, i),
                  ),
                );
              },
            );
          }
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        backgroundColor: const Color(0xFF38BDF8),
        foregroundColor: const Color(0xFF0F172A),
        icon: const Icon(Icons.add, weight: 800),
        label: const Text('ADD MUSIC', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        elevation: 4,
      ),
      bottomNavigationBar: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, mediaItemSnapshot) {
          final currentItem = mediaItemSnapshot.data;
          if (currentItem == null) return const SizedBox.shrink();
          
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const FullPlayerScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                      child: child,
                    );
                  },
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 32),
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 30, offset: const Offset(0, 10))
                ],
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF818CF8)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.music_note, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentItem.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text('TAP TO EXPAND', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                  StreamBuilder<PlaybackState>(
                    stream: audioHandler.playbackState,
                    builder: (context, stateSnapshot) {
                      final isPlaying = stateSnapshot.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            audioHandler.pause();
                          } else {
                            audioHandler.play();
                          }
                        },
                      );
                    }
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});
  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 36),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white, size: 30),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<MediaItem?>(
            stream: audioHandler.mediaItem,
            builder: (context, mediaItemSnapshot) {
              final currentItem = mediaItemSnapshot.data;
              if (currentItem == null) return const SizedBox.shrink();
              
              final duration = currentItem.duration ?? Duration.zero;
              final maxMillis = duration.inMilliseconds.toDouble();

              return Column(
                children: [
                  const Spacer(flex: 1),
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.3), blurRadius: 50, offset: const Offset(0, 20))
                      ],
                    ),
                    child: const Center(child: Icon(Icons.music_note, size: 120, color: Colors.white)),
                  ),
                  const Spacer(flex: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentItem.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                        ),
                        const SizedBox(height: 8),
                        const Text('ローカルファイル', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Spacer(flex: 1),
                  StreamBuilder<Duration>(
                    stream: audioHandler.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final currentMillis = position.inMilliseconds.toDouble();
                      final safeValue = currentMillis > maxMillis ? maxMillis : currentMillis;

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white.withOpacity(0.2),
                                thumbColor: Colors.white,
                                overlayColor: Colors.white.withOpacity(0.1),
                              ),
                              child: Slider(
                                value: safeValue,
                                max: maxMillis > 0 ? maxMillis : 1.0,
                                onChanged: (value) {
                                  audioHandler.seek(Duration(milliseconds: value.toInt()));
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(position), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                Text(_formatDuration(duration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                  ),
                  const Spacer(flex: 1),
                  
                  // 💡 ボタン群の機能を実装
                  StreamBuilder<PlaybackState>(
                    stream: audioHandler.playbackState,
                    builder: (context, stateSnapshot) {
                      final isPlaying = stateSnapshot.data?.playing ?? false;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // シャッフル
                          StreamBuilder<bool>(
                            stream: audioHandler.shuffleModeEnabledStream,
                            initialData: false,
                            builder: (context, snapshot) {
                              final isShuffle = snapshot.data ?? false;
                              return IconButton(
                                icon: Icon(
                                  Icons.shuffle,
                                  color: isShuffle ? const Color(0xFF38BDF8) : Colors.grey,
                                  size: 28,
                                ),
                                onPressed: () {
                                  audioHandler.setShuffleMode(
                                    isShuffle ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all
                                  );
                                },
                              );
                            }
                          ),
                          // 前の曲
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 48),
                            onPressed: () => audioHandler.skipToPrevious(),
                          ),
                          // 再生・一時停止
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: IconButton(
                              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: const Color(0xFF0F172A), size: 48),
                              onPressed: () {
                                if (isPlaying) {
                                  audioHandler.pause();
                                } else {
                                  audioHandler.play();
                                }
                              },
                            ),
                          ),
                          // 次の曲
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 48),
                            onPressed: () => audioHandler.skipToNext(),
                          ),
                          // リピート
                          StreamBuilder<LoopMode>(
                            stream: audioHandler.loopModeStream,
                            initialData: LoopMode.off,
                            builder: (context, snapshot) {
                              final loop = snapshot.data ?? LoopMode.off;
                              return IconButton(
                                icon: Icon(
                                  loop == LoopMode.off
                                      ? Icons.repeat
                                      : loop == LoopMode.all
                                          ? Icons.repeat_on
                                          : Icons.repeat_one_on,
                                  color: loop != LoopMode.off ? const Color(0xFF38BDF8) : Colors.grey,
                                  size: 28,
                                ),
                                onPressed: () {
                                  if (loop == LoopMode.off) {
                                    audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
                                  } else if (loop == LoopMode.all) {
                                    audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
                                  } else {
                                    audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
                                  }
                                },
                              );
                            }
                          ),
                        ],
                      );
                    }
                  ),
                  const Spacer(flex: 2),
                ],
              );
            }
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "--:--";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
