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

import 'dart:async';

import 'package:flutter/material.dart';

/// Subtly animated version of the launcher gradient — a slow drift of the
/// gradient axis. Used as the underlay while a video wallpaper streams, so
/// the home feels alive instead of static/black while the clip loads.
class AnimatedGradientBackground extends StatefulWidget {
  final Gradient gradient;

  const AnimatedGradientBackground({super.key, required this.gradient});

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground> {
  double _t = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Low-frequency update (~8fps): the drift is deliberately slow, and a
    // vsync 60fps rebuild of the whole gradient burned a full core on the
    // Mi Box (launcher at 53% CPU). A Timer at 120ms is visually identical
    // for an 8s ambient loop and ~10x cheaper.
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      setState(() => _t = (_t + 0.0145) % 1.0); // ~8.3s full cycle
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.gradient.colors;
    final linear = widget.gradient is LinearGradient ? widget.gradient as LinearGradient : null;
    final AlignmentGeometry begin = AlignmentGeometry.lerp(
      linear?.begin ?? Alignment.topLeft,
      Alignment.topRight,
      _t * 0.12,
    ) ?? Alignment.topLeft;
    final AlignmentGeometry end = AlignmentGeometry.lerp(
      linear?.end ?? Alignment.bottomRight,
      Alignment.bottomLeft,
      _t * 0.12,
    ) ?? Alignment.bottomRight;
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: colors,
          ),
        ),
      ),
    );
  }
}
