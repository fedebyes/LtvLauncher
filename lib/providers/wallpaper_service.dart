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

import 'package:flauncher/aerial_clips.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/cupertino.dart';
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

  /// Aerial wallpaper from bundled assets — self-contained, no network.
  String? get aerialAssetPath => _settingsService.aerialWallpaperAsset;

  Future<void> setAerialWallpaper(String assetPath) async {
    await _settingsService.setAerialWallpaperAsset(assetPath);
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

  /// Aerial Views-style automatic rotation: every [aerialRotationInterval]
  /// the wallpaper advances to the next bundled clip.
  Timer? _aerialRotationTimer;

  void _startAerialRotation() {
    _aerialRotationTimer?.cancel();
    final current = _settingsService.aerialWallpaperAsset;
    if (current == null) {
      _aerialRotationTimer = null;
      return;
    }
    var index = aerialClips.indexWhere((c) => c.$1 == current);
    if (index < 0) index = 0;
    _aerialRotationTimer = Timer.periodic(aerialRotationInterval, (_) {
      index = (index + 1) % aerialClips.length;
      setAerialWallpaper(aerialClips[index].$1);
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
