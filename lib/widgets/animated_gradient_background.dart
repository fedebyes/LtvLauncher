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

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.gradient.colors;
    final linear = widget.gradient is LinearGradient ? widget.gradient as LinearGradient : null;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value; // 0..1
        final AlignmentGeometry begin = AlignmentGeometry.lerp(
          linear?.begin ?? Alignment.topLeft,
          Alignment.topRight,
          t * 0.12,
        ) ?? Alignment.topLeft;
        final AlignmentGeometry end = AlignmentGeometry.lerp(
          linear?.end ?? Alignment.bottomRight,
          Alignment.bottomLeft,
          t * 0.12,
        ) ?? Alignment.bottomRight;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: colors,
            ),
          ),
        );
      },
    );
  }
}
