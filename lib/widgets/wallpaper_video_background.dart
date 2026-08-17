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

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays a video file as the launcher home background (loop, muted).
/// Ported from Arc Launcher (meddouribadis/arclauncher), GPL-3.0.
class WallpaperVideoBackground extends StatefulWidget {
  final File? file;
  final String? asset;

  const WallpaperVideoBackground({super.key, this.file, this.asset});

  @override
  State<WallpaperVideoBackground> createState() => _WallpaperVideoBackgroundState();
}

class _WallpaperVideoBackgroundState extends State<WallpaperVideoBackground>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  @override
  void didUpdateWidget(WallpaperVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSource = oldWidget.asset ?? oldWidget.file?.path;
    final newSource = widget.asset ?? widget.file?.path;
    if (oldSource != newSource) {
      _disposeController();
      _initController();
    }
  }

  void _initController() {
    final VideoPlayerController controller;
    if (widget.asset != null) {
      controller = VideoPlayerController.asset(widget.asset!);
    } else if (widget.file != null) {
      controller = VideoPlayerController.file(widget.file!);
    } else {
      return;
    }
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted || _controller != controller) {
        _controller = null;
        controller.dispose();
        return;
      }
      controller.setLooping(true);
      controller.setVolume(0);
      controller.play();
      setState(() {});
    }).catchError((error) {
      debugPrint('Video wallpaper initialization failed: $error');
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.resumed) {
      controller.play();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      // Transparent until ready — lets the launcher gradient show through
      // instead of a black screen when the decoder can't play the file.
      return const SizedBox.shrink();
    }

    final size = controller.value.size;
    return RepaintBoundary(
        child: SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: RepaintBoundary(child: VideoPlayer(controller)),
        ),
      ),
    ));
  }
}
