#!/usr/bin/env bash
# Re-run after pulling new code:  cd ~/Meal_Prep && bash update_mac.sh
# Installs backend + Flutter deps, regenerates icons/splash, runs all tests and the analyzer.
# Full output is saved to logs/ so Claude can read it and fix anything that fails.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
LOGS="$ROOT/logs"; mkdir -p "$LOGS"
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
info() { printf "\n\033[1;34m==> %s\033[0m\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
STATUS=0

for p in "$HOME/homebrew/bin" "/Applications/Postgres.app/Contents/Versions/latest/bin" "$HOME/.local/bin" "$HOME/bin" "$HOME/.pub-cache/bin"; do
  [ -d "$p" ] && case ":$PATH:" in *":$p:"*) ;; *) export PATH="$p:$PATH" ;; esac
done

{
  echo "date: $(date)"
  echo "flutter: $(flutter --version 2>/dev/null | head -1)"
  echo "python(uv): $(uv --version 2>/dev/null)"
  echo "psql: $(psql --version 2>/dev/null)"
  echo "pg_isready: $(pg_isready -h localhost -p 5432 2>&1)"
  echo "firebase: $(firebase --version 2>/dev/null || echo missing)"
  echo "flutterfire: $(command -v flutterfire || echo missing)"
  echo "node: $(node --version 2>/dev/null || echo missing)"
  echo "pgadmin: $(ls -d /Applications/pgAdmin*4*.app 2>/dev/null || echo missing)"
} > "$LOGS/environment.log"

# ---------------------------------------------------------------- backend
info "Backend"
cd "$ROOT/backend"
[ -f .env ] || cp .env.example .env
grep -q "^AI_PROVIDER" .env || cat >> .env <<'ENV'

# ---------------- AI (see .env.example for Azure / Claude / Ollama keys) ----------------
AI_PROVIDER=mock
ENV
[ -d .venv ] || uv venv -q -p 3.12 .venv
uv pip install -q -p .venv -r requirements.txt > "$LOGS/backend_install.log" 2>&1 && ok "Python packages installed" \
  || { warn "pip install failed (logs/backend_install.log)"; STATUS=1; }
for db in meal_prep meal_prep_test; do
  psql -h localhost -lqt 2>/dev/null | cut -d'|' -f1 | grep -qw "$db" || createdb -h localhost "$db" 2>/dev/null
done
TEST_DATABASE_URL="postgresql+psycopg://localhost:5432/meal_prep_test" .venv/bin/python -m pytest -q -W ignore \
  > "$LOGS/backend_tests.log" 2>&1 && ok "backend tests pass ($(tail -1 "$LOGS/backend_tests.log"))" \
  || { warn "backend tests failed (logs/backend_tests.log)"; STATUS=1; }
.venv/bin/python -m app.seed >/dev/null 2>&1 && ok "demo cooks seeded"

# ---------------------------------------------------------------- flutter
info "Flutter app"
cd "$ROOT/app"
if [ ! -d ios ] || [ ! -d android ] || [ ! -d web ]; then
  flutter create . --project-name meal_prep --org com.karthikeyan.mealprep --platforms android,ios,web >/dev/null \
    && ok "generated platform folders"
fi
grep -qs "MyApp" test/widget_test.dart && rm -f test/widget_test.dart

flutter pub get > "$LOGS/flutter_pub.log" 2>&1 && ok "packages resolved" \
  || { warn "flutter pub get failed (logs/flutter_pub.log)"; STATUS=1; }

# Dev networking: allow http:// to your Mac's API from emulators/simulators.
MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ]; then
  grep -q 'android.permission.INTERNET' "$MANIFEST" || \
    sed -i '' 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\
    <application#' "$MANIFEST"
  grep -q 'usesCleartextTraffic' "$MANIFEST" || \
    sed -i '' 's#<application#<application android:usesCleartextTraffic="true"#' "$MANIFEST"
  ok "Android: internet + local http allowed"
fi
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! /usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity:NSAllowsLocalNetworking" "$PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$PLIST" 2>/dev/null
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$PLIST" && ok "iOS: local http allowed"
fi
# Firebase iOS SDK needs iOS 15+
if [ -f ios/Podfile ]; then
  sed -i '' "s/^# platform :ios, .*/platform :ios, '15.0'/; s/^platform :ios, '1[0-4].0'/platform :ios, '15.0'/" ios/Podfile
fi
sed -i '' "s/IPHONEOS_DEPLOYMENT_TARGET = 1[0-4].0;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g" ios/Runner.xcodeproj/project.pbxproj 2>/dev/null

dart run flutter_launcher_icons > "$LOGS/icons.log" 2>&1 && ok "app icons generated" || warn "icon generation failed (logs/icons.log)"
dart run flutter_native_splash:create > "$LOGS/splash.log" 2>&1 && ok "splash screen generated" || warn "splash failed (logs/splash.log)"

flutter analyze > "$LOGS/flutter_analyze.log" 2>&1 && ok "flutter analyze: no issues" \
  || { warn "flutter analyze found issues (logs/flutter_analyze.log)"; grep -E "error •" "$LOGS/flutter_analyze.log" | head -15; STATUS=1; }
flutter test > "$LOGS/flutter_test.log" 2>&1 && ok "flutter tests pass" \
  || { warn "flutter tests failed (logs/flutter_test.log)"; STATUS=1; }

info "Done"
if [ $STATUS -eq 0 ]; then
  cat <<MSG
  Everything checks out.
    API:  cd ~/Meal_Prep && bash run_backend.sh        → http://localhost:8000/docs
    App:  cd ~/Meal_Prep/app && flutter run -d chrome  (or an emulator / simulator)
MSG
else
  echo "  Some steps need attention. Tell Claude \"check the logs\" and it will read ~/Meal_Prep/logs and fix them."
fi
exit $STATUS
