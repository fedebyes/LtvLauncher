#!/usr/bin/env bash
# Restore LTvLauncher state after a reinstall (signature change = uninstall first).
#
# Captured from the live box on 2026-10-19 before the poster-fix reinstall:
#   - HOME default          : com.leanbitlab.ltvL (LTvLauncher upstream 2026.10.03)
#   - Stock launcher        : com.google.android.tvlauncher DISABLED (fallback)
#   - READ_TV_LISTINGS      : granted
#   - Notification listener : LTvLauncher appended to enabled_notification_listeners
#   - Accessibility         : DeepColorAccessibilityService + KDE MouseReceiverService
#   - Wallpaper             : Gradient "Great Whale", time-based OFF
#   - Continue Watching     : enabled, defaults (normal size, no max limit)
#
# Usage:  bash restore_ltv_state.sh [box_ip]
set -euo pipefail

BOX="${1:-192.168.1.137:5555}"
PKG="com.leanbitlab.ltvL"
NLS="$PKG/$PKG.LauncherNotificationListenerService"

say() { printf '\n==> %s\n' "$*"; }

say "adb connect $BOX"
adb connect "$BOX" >/dev/null 2>&1 || true
adb -s "$BOX" wait-for-device

say "1/7 re-grant READ_TV_LISTINGS (Continue Watching row)"
adb -s "$BOX" shell pm grant "$PKG" android.permission.READ_TV_LISTINGS || \
  echo "   (already granted)"

say "2/7 notification listener (append, never overwrite)"
CUR=$(adb -s "$BOX" shell settings get secure enabled_notification_listeners | tr -d '\r')
case "$CUR" in
  *leanbitlab*) echo "   already present" ;;
  *)
    if [ -z "$CUR" ] || [ "$CUR" = "null" ]; then NEW="$NLS"; else NEW="$CUR:$NLS"; fi
    adb -s "$BOX" shell settings put secure enabled_notification_listeners "$NEW"
    echo "   appended"
    ;;
esac
# settings put alone is not enough: the NotificationManager only reloads the list
# through this command. Without it the listener stays "enabled" but never binds.
adb -s "$BOX" shell cmd notification allow_listener "$NLS" || true

say "3/7 accessibility services (re-verify, append if missing)"
ACC=$(adb -s "$BOX" shell settings get secure enabled_accessibility_services | tr -d '\r')
for SVC in "dev.fedebyes.miboxhdrfix/.DeepColorAccessibilityService" \
           "org.kde.kdeconnect_tp/org.kde.kdeconnect.plugins.mousereceiver.MouseReceiverService"; do
  case "$ACC" in
    *"$SVC"*) : ;;
    *) if [ -z "$ACC" ] || [ "$ACC" = "null" ]; then ACC="$SVC"; else ACC="$ACC:$SVC"; fi ;;
  esac
done
adb -s "$BOX" shell settings put secure enabled_accessibility_services "$ACC"
echo "   $ACC"

say "4/7 keep stock launcher disabled (fallback, reversible with pm enable)"
adb -s "$BOX" shell pm disable-user --user 0 com.google.android.tvlauncher >/dev/null 2>&1 || true

say "5/7 force-stop + start so the listener actually binds"
adb -s "$BOX" shell am force-stop "$PKG"
sleep 2
adb -s "$BOX" shell am start -n "$PKG/$PKG.MainActivity" >/dev/null
sleep 6

say "6/7 verify"
echo "   HOME resolves to:"
adb -s "$BOX" shell cmd package resolve-activity --brief \
  -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1
echo "   live notification listeners:"
adb -s "$BOX" shell dumpsys notification --noredact | grep -A6 'Live notification listeners' | head -4
echo "   READ_TV_LISTINGS:"
adb -s "$BOX" shell dumpsys package "$PKG" | grep -E 'READ_TV_LISTINGS: granted' | head -2

say "7/7 manual (cannot be scripted without root / in-app UI)"
cat <<'EOF'
   - Wallpaper: Interface -> Wallpaper -> Gradient -> "Great Whale"
     (was: time-based OFF, Gradient Great Whale)
   - Continue Watching card size / max items / hidden entries: defaults
   - Favorites order: Jellyfin -> SmartTube -> Prime Video -> LTv (in-app)
EOF
echo
echo "Done."
