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
import 'package:flauncher/l10n/app_localizations.dart';

import 'package:flauncher/widgets/rounded_switch_list_tile.dart';

/// Aerial wallpaper clips streamed from the Asus LAN server (see
/// ~/srv/aerial + systemd --user aerial-http.service on Asus).
/// Each clip is 720p H.264 <10MB; streamed, not bundled.
const List<(String, String)> _aerialClips = [
  ('http://192.168.1.13:8900/aerial_1.mp4', 'Aerial — Beach'),
  ('http://192.168.1.13:8900/aerial_2.mp4', 'Aerial — City'),
  ('http://192.168.1.13:8900/aerial_3.mp4', 'Aerial — Winter'),
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
          for (final clip in _aerialClips)
            FocusableSettingsTile(
              leading: Icon(Icons.landscape_outlined),
              title: Text(clip.$2, style: Theme.of(context).textTheme.bodyMedium),
              onPressed: () async {
                await context.read<WallpaperService>().setAerialWallpaper(clip.$1);
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
