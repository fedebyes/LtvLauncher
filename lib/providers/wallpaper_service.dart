/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flauncher/aerial_clips.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class WallpaperService extends ChangeNotifier {
  final FLauncherChannel _fLauncherChannel;
  final SettingsService _settingsService;

  late File _wallpaperFile;
  late File _wallpaperDayFile;
  late File _wallpaperNightFile;
  late File _wallpaperVideoFile;
  late File _wallpaperDayVideoFile;
  late File _wallpaperNightVideoFile;
  Timer? _timer;

  ImageProvider? _wallpaper;
  int _version = 0;
  int _updateWallpaperCallCount = 0;
  bool _lastVideoActive = false;
  bool _initialized = false;

  ImageProvider?  get wallpaper     => _wallpaper;
  int             get version       => _version;
  bool            get isInitialized => _initialized;

  File? get wallpaperVideoFile {
    if (!isInitialized) return null; // late fields not set yet
    final f = _resolveActiveVideoFile();
    return (f != null && f.existsSync()) ? f : null;
  }

  FLauncherGradient get gradient => FLauncherGradients.all.firstWhere(
        (gradient) => gradient.uuid == _settingsService.gradientUuid,
        orElse: () => FLauncherGradients.pitchBlack,
      );

  WallpaperService(this._fLauncherChannel, this._settingsService) :
    _wallpaper = null
  {
    _settingsService.addListener(_onSettingsChanged);
    _init();
  }

  bool _lastTimeBasedEnabled = false;

  void _onSettingsChanged() {
    final enabled = _settingsService.timeBasedWallpaperEnabled;
    if (enabled != _lastTimeBasedEnabled) {
      _lastTimeBasedEnabled = enabled;
      _updateTimerState();
      _updateWallpaper();
    }
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _timer?.cancel();
    _aerialRotationTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final directory = await getApplicationDocumentsDirectory();
    _wallpaperFile = File("${directory.path}/wallpaper");
    _wallpaperDayFile = File("${directory.path}/wallpaper_day");
    _wallpaperNightFile = File("${directory.path}/wallpaper_night");
    _wallpaperVideoFile = File("${directory.path}/wallpaper_video");
    _wallpaperDayVideoFile = File("${directory.path}/wallpaper_day_video");
    _wallpaperNightVideoFile = File("${directory.path}/wallpaper_night_video");

    _lastTimeBasedEnabled = _settingsService.timeBasedWallpaperEnabled;
    await _loadRemoteCache();
    await _updateWallpaper();
    _updateTimerState();
    _initialized = true;
    _startAerialRotation();
  }

  void _updateTimerState() {
    final enabled = _settingsService.timeBasedWallpaperEnabled;
    if (enabled && (_timer == null || !_timer!.isActive)) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateWallpaper());
    } else if (!enabled && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _updateWallpaper({bool force = false}) async {
    final callId = ++_updateWallpaperCallCount;
    final now = DateTime.now();
    final isDay = now.hour >= 6 && now.hour < 18;
    final enabled = _settingsService.timeBasedWallpaperEnabled;

    final videoActive = _resolveActiveVideoFile() != null;
    ImageProvider? newWallpaper;

    if (!videoActive) {
      if (enabled) {
        if (isDay && await _wallpaperDayFile.exists()) {
          newWallpaper = FileImage(_wallpaperDayFile);
        } else if (!isDay && await _wallpaperNightFile.exists()) {
          newWallpaper = FileImage(_wallpaperNightFile);
        } else if (await _wallpaperFile.exists()) {
          newWallpaper = FileImage(_wallpaperFile); // Fallback
        }
      } else {
        if (await _wallpaperFile.exists()) {
          newWallpaper = FileImage(_wallpaperFile);
        }
      }
    }

    if (callId == _updateWallpaperCallCount) {
      if (_wallpaper != newWallpaper || videoActive != _lastVideoActive || force) {
        _wallpaper = newWallpaper;
        _lastVideoActive = videoActive;
        notifyListeners();
      }
    }
  }

  File? _resolveActiveVideoFile() {
    if (!isInitialized) return null;
    final now = DateTime.now();
    final isDay = now.hour >= 6 && now.hour < 18;
    final enabled = _settingsService.timeBasedWallpaperEnabled;

    if (enabled) {
      if (isDay && _wallpaperDayVideoFile.existsSync()) {
        return _wallpaperDayVideoFile;
      }
      if (!isDay && _wallpaperNightVideoFile.existsSync()) {
        return _wallpaperNightVideoFile;
      }
      if (_wallpaperVideoFile.existsSync()) {
        return _wallpaperVideoFile;
      }
    } else if (_wallpaperVideoFile.existsSync()) {
      return _wallpaperVideoFile;
    }
    return null;
  }

  Future<void> pickWallpaper() async {
    await _pickAndSave(_wallpaperFile);
  }

  Future<void> pickWallpaperDay() async {
    await _pickAndSave(_wallpaperDayFile);
  }

  Future<void> pickWallpaperNight() async {
    await _pickAndSave(_wallpaperNightFile);
  }

  Future<void> pickVideoWallpaper() async {
    await _pickAndSaveVideo(_wallpaperVideoFile);
  }

  Future<void> pickVideoWallpaperDay() async {
    await _pickAndSaveVideo(_wallpaperDayVideoFile);
  }

  Future<void> pickVideoWallpaperNight() async {
    await _pickAndSaveVideo(_wallpaperNightVideoFile);
  }

  /// Aerial wallpaper source: a bundled asset path ('assets/...') or a
  /// remote URL ('http...') fetched from the Aerial Views library.
  String? get aerialAssetPath {
    final s = _settingsService.aerialWallpaperAsset;
    return (s != null && s.startsWith('assets/')) ? s : null;
  }

  String? get aerialVideoUrl {
    final s = _settingsService.aerialWallpaperAsset;
    return (s != null && s.startsWith('http')) ? s : null;
  }

  Future<void> setAerialWallpaper(String source) async {
    await _settingsService.setAerialWallpaperAsset(source);
    _version++;
    _startAerialRotation();
    notifyListeners();
  }

  Future<void> clearAerialWallpaper() async {
    await _settingsService.setAerialWallpaperAsset(null);
    _version++;
    _aerialRotationTimer?.cancel();
    _aerialRotationTimer = null;
    notifyListeners();
  }

  // --- Aerial Views-style remote library (auto-fetch) ---

  final List<String> _remoteAerialUrls = [];
  int get remoteAerialCount => _remoteAerialUrls.length;

  File? _remoteCacheFile;

  static const Map<String, (String, String)> _aerialManifests = {
    // Aerial Views open-source manifests, bundled in the APK (like the
    // original app does) — no network needed for the video list.
    'apple': ('assets/manifests/tvos26.json', 'url-1080-H264'), // Apple (139)
    'amazon': ('assets/manifests/fireos8.json', 'url-1080-SDR'), // Amazon Fire TV (112)
    'jetson': ('assets/manifests/comm1.json', 'url-1080-H264'), // Jetson Creative (20)
    'robin': ('assets/manifests/comm2.json', 'url-1080-H264'), // Robin Fourcade (18)
  };

  /// Loads one source set ('apple' | 'amazon' | 'jetson' | 'robin' | 'all')
  /// from the bundled manifests at 1080p "low quality" variants, caches the
  /// URL list, and starts rotating through only that set.
  Future<int> fetchAerialLibrary(String sourceKey) async {
    final urls = <String>{};
    for (final entry in _aerialManifests.entries) {
      if (sourceKey != 'all' && entry.key != sourceKey) continue;
      final fetched = await _fetchManifest1080p(entry.value.$1, entry.value.$2);
      urls.addAll(fetched);
    }
    _remoteAerialUrls
      ..clear()
      ..addAll(urls);
    await _saveRemoteCache();
    if (_remoteAerialUrls.isNotEmpty) {
      await setAerialWallpaper(_remoteAerialUrls.first);
    }
    return _remoteAerialUrls.length;
  }

  Future<List<String>> _fetchManifest1080p(String assetPath, String urlKey) async {
    try {
      final body = await rootBundle.loadString(assetPath);
      final data = jsonDecode(body);
      final assets = (data is Map ? data['assets'] : null);
      if (assets is! List) return const [];
      final out = <String>[];
      for (final asset in assets) {
        if (asset is! Map) continue;
        final v = asset[urlKey];
        if (v is String && v.isNotEmpty) {
          // Apple's CDN cert is invalid — Aerial Views plays it over http.
          out.add(v.startsWith('https://sylvan.apple.com')
              ? v.replaceFirst('https://', 'http://')
              : v);
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _loadRemoteCache() async {
    final dir = await getApplicationDocumentsDirectory();
    _remoteCacheFile = File('${dir.path}/aerial_library.json');
    try {
      if (!await _remoteCacheFile!.exists()) return;
      final data = jsonDecode(await _remoteCacheFile!.readAsString());
      if (data is List) {
        _remoteAerialUrls
          ..clear()
          ..addAll(data.whereType<String>());
      }
    } catch (_) {
      // Corrupt cache — ignore, will refetch.
    }
  }

  Future<void> _saveRemoteCache() async {
    try {
      await _remoteCacheFile?.writeAsString(jsonEncode(_remoteAerialUrls));
    } catch (_) {
      // Non-fatal.
    }
  }

  /// Aerial Views-style automatic rotation: every [aerialRotationInterval]
  /// the wallpaper advances to the next clip (remote library or bundled).
  Timer? _aerialRotationTimer;

  void _startAerialRotation() {
    _aerialRotationTimer?.cancel();
    final current = _settingsService.aerialWallpaperAsset;
    if (current == null) {
      _aerialRotationTimer = null;
      return;
    }
    final bool remote = current.startsWith('http');
    final List<String> list = remote
        ? List.of(_remoteAerialUrls)
        : aerialClips.map((c) => c.$1).toList();
    if (list.isEmpty) {
      _aerialRotationTimer = null;
      return;
    }
    var index = list.indexOf(current);
    if (index < 0) index = 0;
    _aerialRotationTimer = Timer.periodic(aerialRotationInterval, (_) {
      index = (index + 1) % list.length;
      setAerialWallpaper(list[index]);
    });
  }

  Future<void> _pickAndSave(File targetFile) async {
    if (!await _fLauncherChannel.checkForGetContentAvailability()) {
      throw NoFileExplorerException();
    }

    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Replacing an image wallpaper with another image: drop any video wallpaper
      // so the image is what gets rendered (video takes precedence otherwise).
      await _deleteVideoWallpapers();

      // Use stream for memory efficiency
      final readStream = pickedFile.openRead();
      final writeStream = targetFile.openWrite();
      await readStream.cast<List<int>>().pipe(writeStream);

      // Evict from cache to ensure UI updates
      await FileImage(targetFile).evict();

      _version++;
      await _updateWallpaper(force: true);
    }
  }

  Future<void> _pickAndSaveVideo(File targetFile) async {
    if (!await _fLauncherChannel.checkForGetContentAvailability()) {
      throw NoFileExplorerException();
    }

    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Use stream for memory efficiency
      final readStream = pickedFile.openRead();
      final writeStream = targetFile.openWrite();
      await readStream.cast<List<int>>().pipe(writeStream);

      _version++;
      await _updateWallpaper(force: true);
    }
  }

  Future<void> _deleteVideoWallpapers() async {
    for (final f in [_wallpaperVideoFile, _wallpaperDayVideoFile, _wallpaperNightVideoFile]) {
      if (await f.exists()) {
        await f.delete();
      }
    }
  }

  Future<void> setGradient(FLauncherGradient fLauncherGradient) async {
    if (await _wallpaperFile.exists()) {
      await _wallpaperFile.delete();
    }
    await _deleteVideoWallpapers();

    _settingsService.setGradientUuid(fLauncherGradient.uuid);
    notifyListeners();
  }
}

class NoFileExplorerException implements Exception {}
