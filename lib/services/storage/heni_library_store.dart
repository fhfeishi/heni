import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../domain/playback/playback_mode.dart';

final heniLibraryStoreProvider = Provider<HeniLibraryStore>((ref) {
  return FileHeniLibraryStore();
});

abstract interface class HeniLibraryStore {
  Future<HeniLibraryConfig?> read();
  Future<void> write(HeniLibraryConfig config);
}

class HeniLibraryConfig {
  const HeniLibraryConfig({
    this.libraryDirectories = const [],
    this.libraryFiles = const [],
    this.playlists = const [],
    this.activePlaylistId,
    this.sceneryImagePaths = const [],
    this.activePaletteName,
    this.activeUiStyle,
    this.playbackModeName,
    this.volumeLevel,
    this.recursiveScan = true,
    this.includeVideo = true,
    this.autoplayOnLoad = true,
  });

  factory HeniLibraryConfig.fromJson(Map<String, Object?> json) {
    return HeniLibraryConfig(
      libraryDirectories: _stringList(json['libraryDirectories']),
      libraryFiles: _stringList(json['libraryFiles']),
      playlists: _objectList(
        json['playlists'],
      ).map(HeniPlaylistConfig.fromJson).toList(growable: false),
      activePlaylistId: _string(json['activePlaylistId']),
      sceneryImagePaths: _stringList(json['sceneryImagePaths']),
      activePaletteName: _string(json['activePaletteName']),
      activeUiStyle: _string(json['activeUiStyle']),
      playbackModeName: _string(json['playbackModeName']),
      volumeLevel: _double(json['volumeLevel']),
      recursiveScan: _bool(json['recursiveScan']) ?? true,
      includeVideo: _bool(json['includeVideo']) ?? true,
      autoplayOnLoad: _bool(json['autoplayOnLoad']) ?? true,
    );
  }

  final List<String> libraryDirectories;
  final List<String> libraryFiles;
  final List<HeniPlaylistConfig> playlists;
  final String? activePlaylistId;
  final List<String> sceneryImagePaths;
  final String? activePaletteName;
  final String? activeUiStyle;
  final String? playbackModeName;
  final double? volumeLevel;
  final bool recursiveScan;
  final bool includeVideo;
  final bool autoplayOnLoad;

  HeniPlaybackMode? get playbackMode {
    final modeName = playbackModeName;
    if (modeName == null) {
      return null;
    }
    return HeniPlaybackMode.values.firstWhere(
      (mode) => mode.name == modeName,
      orElse: () => HeniPlaybackMode.sequence,
    );
  }

  bool get isEmpty {
    return libraryDirectories.isEmpty &&
        libraryFiles.isEmpty &&
        playlists.isEmpty &&
        activePlaylistId == null &&
        sceneryImagePaths.isEmpty &&
        activePaletteName == null &&
        activeUiStyle == null &&
        playbackModeName == null &&
        volumeLevel == null;
  }

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': 1,
      'libraryDirectories': libraryDirectories,
      'libraryFiles': libraryFiles,
      'playlists': playlists.map((playlist) => playlist.toJson()).toList(),
      'activePlaylistId': activePlaylistId,
      'sceneryImagePaths': sceneryImagePaths,
      'activePaletteName': activePaletteName,
      'activeUiStyle': activeUiStyle,
      'playbackModeName': playbackModeName,
      'volumeLevel': volumeLevel,
      'recursiveScan': recursiveScan,
      'includeVideo': includeVideo,
      'autoplayOnLoad': autoplayOnLoad,
    };
  }
}

class HeniPlaylistConfig {
  const HeniPlaylistConfig({
    required this.id,
    required this.name,
    required this.itemPaths,
    this.description = '',
  });

  factory HeniPlaylistConfig.fromJson(Map<String, Object?> json) {
    return HeniPlaylistConfig(
      id: _string(json['id']) ?? '',
      name: _string(json['name']) ?? '未命名歌单',
      description: _string(json['description']) ?? '',
      itemPaths: _stringList(json['itemPaths']),
    );
  }

  final String id;
  final String name;
  final String description;
  final List<String> itemPaths;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'itemPaths': itemPaths,
    };
  }
}

class FileHeniLibraryStore implements HeniLibraryStore {
  FileHeniLibraryStore({File? file}) : _file = file ?? _defaultFile();

  final File _file;

  File get file => _file;

  @override
  Future<HeniLibraryConfig?> read() async {
    if (!await _file.exists()) {
      return null;
    }

    final text = await _file.readAsString();
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      return HeniLibraryConfig.fromJson(_objectMap(decoded));
    }

    return null;
  }

  @override
  Future<void> write(HeniLibraryConfig config) async {
    await _file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file.writeAsString(encoder.convert(config.toJson()));
  }

  static File _defaultFile() {
    final environment = Platform.environment;
    final base = switch (Platform.operatingSystem) {
      'windows' =>
        environment['APPDATA'] ??
            p.join(environment['USERPROFILE'] ?? '.', 'AppData', 'Roaming'),
      'linux' =>
        environment['XDG_CONFIG_HOME'] ??
            p.join(environment['HOME'] ?? '.', '.config'),
      'macos' => p.join(
        environment['HOME'] ?? '.',
        'Library',
        'Application Support',
      ),
      _ => environment['HOME'] ?? '.',
    };

    return File(p.join(base, 'Heni', 'library.json'));
  }
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }

  return [
    for (final entry in value)
      if (entry case final String text) text,
  ];
}

List<Map<String, Object?>> _objectList(Object? value) {
  if (value is! List) {
    return const [];
  }

  return [
    for (final entry in value)
      if (entry is Map) _objectMap(entry),
  ];
}

Map<String, Object?> _objectMap(Map<dynamic, dynamic> value) {
  return {
    for (final entry in value.entries)
      if (entry.key case final String key) key: entry.value,
  };
}

String? _string(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

bool? _bool(Object? value) {
  return value is bool ? value : null;
}

double? _double(Object? value) {
  return switch (value) {
    final int number => number.toDouble(),
    final double number => number,
    _ => null,
  };
}
