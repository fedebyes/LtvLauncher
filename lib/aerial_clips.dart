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
/// directly from the APK — self-contained, no network. All 720p H.264 Main
/// (light on the box's RAM/decoder). Rotated automatically when an aerial
/// wallpaper is selected.
const List<(String, String)> aerialClips = [
  ('assets/aerial/aerial_1.mp4', 'Beach — Inasa'),
  ('assets/aerial/aerial_2.mp4', 'City — Hudson Yards'),
  ('assets/aerial/aerial_3.mp4', 'Winter — Park City'),
  ('assets/aerial/aerial_4.mp4', 'Las Vegas'),
  ('assets/aerial/aerial_5.mp4', 'Lone Ranch Beach'),
  ('assets/aerial/aerial_6.mp4', 'Big Sur'),
  ('assets/aerial/aerial_7.mp4', 'London'),
  ('assets/aerial/aerial_8.mp4', 'San Francisco'),
  ('assets/aerial/aerial_9.mp4', 'Coral Reef'),
  ('assets/aerial/aerial_10.mp4', 'Piton des Neiges'),
  ('assets/aerial/aerial_11.mp4', 'Sea of Clouds'),
];

/// How often the aerial wallpaper advances to the next clip.
const Duration aerialRotationInterval = Duration(minutes: 5);
