#!/usr/bin/env bash
# One-time setup for the Meal Prep project on macOS.
# Checks each tool, installs only what's missing, then sets up the backend + Flutter app.
#   cd ~/Meal_Prep && bash setup_mac.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
info() { printf "\n\033[1;34m==> %s\033[0m\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
die()  { printf "  \033[31m✗ %s\033[0m\n" "$*"; exit 1; }

add_path() {  # add a dir to PATH now and in ~/.zshrc
  case ":$PATH:" in *":$1:"*) ;; *) export PATH="$1:$PATH" ;; esac
  grep -qs "export PATH=\"$1:\$PATH\"" ~/.zshrc || echo "export PATH=\"$1:\$PATH\"" >> ~/.zshrc
}

# ---------------------------------------------------------------- Homebrew
info "Homebrew"
[ -x "$HOME/homebrew/bin/brew" ] && add_path "$HOME/homebrew/bin"
command -v brew >/dev/null || die "Homebrew not found. Install it from https://brew.sh and re-run."
ok "brew $(brew --version | head -1 | awk '{print $2}') at $(brew --prefix)"

# ---------------------------------------------------------------- PostgreSQL
info "PostgreSQL"
PGAPP_BIN="/Applications/Postgres.app/Contents/Versions/latest/bin"
[ -d "$PGAPP_BIN" ] && add_path "$PGAPP_BIN"
if command -v psql >/dev/null; then
  ok "already installed: $(psql --version)"
else
  warn "not installed → installing Postgres.app (prebuilt, no compiling)"
  brew install --cask postgres-app || die "Postgres.app install failed"
  add_path "$PGAPP_BIN"
fi

if ! pg_isready -q -h localhost -p 5432; then
  [ -d /Applications/Postgres.app ] && open -a Postgres
  warn "Postgres isn't running. In the Postgres.app window click 'Initialize' (first time) or 'Start'."
  printf "  waiting for Postgres on localhost:5432 "
  for _ in $(seq 1 90); do pg_isready -q -h localhost -p 5432 && break; printf "."; sleep 2; done
  echo
  pg_isready -q -h localhost -p 5432 || die "Postgres still not reachable on 5432."
fi
ok "server is running on localhost:5432"
warn "If macOS/Postgres.app asks to allow a connection from Terminal or Python, click OK."

for db in meal_prep meal_prep_test; do
  if psql -h localhost -lqt | cut -d'|' -f1 | grep -qw "$db"; then ok "database $db exists"
  else createdb -h localhost "$db" && ok "created database $db"; fi
done

# ---------------------------------------------------------------- pgAdmin
info "pgAdmin 4"
if ls -d /Applications/pgAdmin*4*.app >/dev/null 2>&1; then ok "already installed"
else brew install --cask pgadmin4 && ok "installed pgAdmin 4"; fi

# ---------------------------------------------------------------- Python (uv)
info "Python toolchain (uv)"
[ -x "$HOME/.local/bin/uv" ] && add_path "$HOME/.local/bin"
if ! command -v uv >/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh || die "uv install failed"
  add_path "$HOME/.local/bin"
fi
ok "$(uv --version)"

# ---------------------------------------------------------------- Firebase CLI
info "Firebase CLI"
mkdir -p "$HOME/bin" && add_path "$HOME/bin"
if command -v firebase >/dev/null; then ok "already installed: firebase $(firebase --version)"
else
  warn "not installed → downloading standalone binary to ~/bin/firebase (no Node needed)"
  curl -fsSL -o "$HOME/bin/firebase" https://firebase.tools/bin/macos/latest || die "Firebase CLI download failed"
  chmod +x "$HOME/bin/firebase"
  ok "installed firebase $(firebase --version)"
fi

# ---------------------------------------------------------------- Flutter + FlutterFire
info "Flutter & FlutterFire CLI"
command -v flutter >/dev/null || die "flutter not on PATH"
ok "$(flutter --version 2>/dev/null | head -1)"
add_path "$HOME/.pub-cache/bin"
if command -v flutterfire >/dev/null; then ok "flutterfire already installed"
else dart pub global activate flutterfire_cli >/dev/null && ok "installed flutterfire CLI"; fi

# ---------------------------------------------------------------- Node (optional)
info "Node.js (optional — only for Firebase Cloud Functions later)"
if command -v node >/dev/null; then ok "node $(node --version)"
else warn "not installed — skipping (not needed right now). Later: brew install node"; fi

# ---------------------------------------------------------------- Project
# Everything project-specific (backend deps, tests, Flutter packages, icons, analyzer) lives in
# update_mac.sh so you can re-run it after every code change.
info "Project setup"
bash "$ROOT/update_mac.sh"
