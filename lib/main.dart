import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'models/track.dart';
import 'services/audio_handler.dart';

late MyAudioHandler audioHandler;

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
  Widget build(BuildContext context) =>
      MaterialApp(home: PlayerPage(), debugShowCheckedModeBanner: false);
}

class PlayerPage extends StatefulWidget {
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final List<Track> _tracks = [];

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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Music')),
      body: ListView.builder(
        itemCount: _tracks.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(_tracks[i].title),
          onTap: () => audioHandler.loadFile(
            _tracks[i].file.path,
            _tracks[i].title,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _import,
        child: const Icon(Icons.add),
      ),
    );
  }
}
