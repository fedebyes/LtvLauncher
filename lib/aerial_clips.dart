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

/// Aerial wallpaper clips bundled in the app (assets/aerial/), played
/// directly from the APK — self-contained, no network. 720p H.264 Main.
/// Rotated automatically when an aerial wallpaper is selected.
const List<(String, String)> aerialClips = [
  ('assets/aerial/aerial_1.mp4', 'Aerial — Beach'),
  ('assets/aerial/aerial_2.mp4', 'Aerial — City'),
  ('assets/aerial/aerial_3.mp4', 'Aerial — Winter'),
];

/// How often the aerial wallpaper advances to the next clip.
const Duration aerialRotationInterval = Duration(minutes: 5);
