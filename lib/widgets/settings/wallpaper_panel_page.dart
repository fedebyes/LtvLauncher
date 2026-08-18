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

import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/aerial_clips.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import 'package:flauncher/widgets/rounded_switch_list_tile.dart';

/// Remote aerial source sets selectable from the wallpaper panel.
/// (key, label, icon)
const List<(String, String, IconData)> _aerialSources = [
  ('apple', 'Auto aerial — Apple', Icons.apple),
  ('amazon', 'Auto aerial — Amazon', Icons.cloud_outlined),
  ('jetson', 'Auto aerial — Jetson Creative', Icons.landscape_outlined),
  ('robin', 'Auto aerial — Robin Fourcade', Icons.photo_library_outlined),
  ('all', 'Auto aerial — All sources', Icons.cloud_download_outlined),
];

class WallpaperPanelPage extends StatelessWidget {
  static const String routeName = "wallpaper_panel";

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Column(
        children: [
          Text(localizations.wallpaper, style: Theme.of(context).textTheme.titleLarge),
          Divider(),
          Consumer<SettingsService>(
            builder: (_, settings, __) {
              return RoundedSwitchListTile(
                title: Text(localizations.timeBasedWallpaper),
                secondary: Icon(Icons.access_time),
                value: settings.timeBasedWallpaperEnabled,
                onChanged: (value) => settings.setTimeBasedWallpaperEnabled(value),
              );
            }
          ),
          Consumer<SettingsService>(
            builder: (_, settings, __) {
              if (settings.timeBasedWallpaperEnabled) {
                return Column(
                  children: [
                    FocusableSettingsTile(
                      leading: Icon(Icons.wb_sunny),
                      title: Text(localizations.pickDayWallpaper),
                      onPressed: () => _pickWallpaper(context, (s) => s.pickWallpaperDay(), localizations),
                    ),
                    FocusableSettingsTile(
                      leading: Icon(Icons.nights_stay),
                      title: Text(localizations.pickNightWallpaper),
                      onPressed: () => _pickWallpaper(context, (s) => s.pickWallpaperNight(), localizations),
                    ),
                    FocusableSettingsTile(
                      leading: Icon(Icons.wb_sunny),
                      title: Text(localizations.pickDayVideoWallpaper),
                      onPressed: () => _pickWallpaper(context, (s) => s.pickVideoWallpaperDay(), localizations),
                    ),
                    FocusableSettingsTile(
                      leading: Icon(Icons.videocam_outlined),
                      title: Text(localizations.pickNightVideoWallpaper),
                      onPressed: () => _pickWallpaper(context, (s) => s.pickVideoWallpaperNight(), localizations),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    FocusableSettingsTile(
                      autofocus: true,
                      leading: Icon(Icons.gradient),
                      title: Text(localizations.gradient, style: Theme.of(context).textTheme.bodyMedium),
                      onPressed: () => Navigator.of(context).pushNamed(GradientPanelPage.routeName),
                    ),
                    FocusableSettingsTile(
                      leading: Icon(Icons.insert_drive_file_outlined),
                      title: Text(localizations.picture, style: Theme.of(context).textTheme.bodyMedium),
                      onPressed: () => _pickWallpaper(context, (s) => s.pickWallpaper(), localizations),
                    ),
                    FocusableSettingsTile(
                      leading: Icon(Icons.videocam_outlined),
                      title: Text(localizations.video, style: Theme.of(context).textTheme.bodyMedium),
                      onPressed: () => _pickWallpaper(context, (s) => s.pickVideoWallpaper(), localizations),
                    ),
                  ],
                );
              }
            }
          ),
          const Divider(),
          Text(localizations.aerial, style: Theme.of(context).textTheme.titleMedium),
          FocusableSettingsTile(
            leading: Icon(Icons.landscape_outlined),
            title: Text('Offline aerial — 720p (${aerialClips.length} clips)', style: Theme.of(context).textTheme.bodyMedium),
            onPressed: () async {
              final service = context.read<WallpaperService>();
              await service.setAerialWallpaper(aerialClips.first.$1);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 3),
                  content: Text('Offline 720p set — ${aerialClips.length} clips, rotating every 5 min'),
                ),
              );
            },
          ),
          for (final source in _aerialSources)
            FocusableSettingsTile(
              leading: Icon(source.$3),
              title: Text(source.$2, style: Theme.of(context).textTheme.bodyMedium),
              onPressed: () async {
                final service = context.read<WallpaperService>();
                final count = await service.fetchAerialLibrary(source.$1);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 4),
                    content: Text(count > 0
                        ? '${source.$2}: $count videos (1080p) — rotating every 5 min'
                        : 'No videos found'),
                  ),
                );
              },
            ),
          FocusableSettingsTile(
            leading: Icon(Icons.stop_circle_outlined),
            title: Text('Clear aerial (gradient)', style: Theme.of(context).textTheme.bodyMedium),
            onPressed: () async {
              await context.read<WallpaperService>().clearAerialWallpaper();
            },
          ),
        ],
    );
  }

  Future<void> _pickWallpaper(BuildContext context, Future<void> Function(WallpaperService) action, AppLocalizations localizations) async {
    try {
      await action(context.read<WallpaperService>());
    } on NoFileExplorerException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 8),
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text(localizations.dialogTextNoFileExplorer)
            ],
          ),
        ),
      );
    }
  }
}
