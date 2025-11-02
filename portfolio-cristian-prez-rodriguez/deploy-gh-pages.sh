#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="${REPO_NAME:-$(basename "$PWD" | tr '[:upper:] ' '[:lower:]-' | sed 's/[^a-z0-9._-]//g')}"
VISIBILITY="${VISIBILITY:-public}"
OWNER="${OWNER:-}"
CNAME="${CNAME:-}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Falta '$1'. Instálalo y reintenta."; exit 1; }; }
need git
need gh

if ! gh auth status >/dev/null 2>&1; then
  echo "🔐 Iniciando sesión en GitHub…"
  gh auth login -w -p https
fi

: > .nojekyll
[ -n "$CNAME" ] && echo "$CNAME" > CNAME

[ -d .git ] || git init
git add -A
git commit -m "Initial commit" >/dev/null 2>&1 || echo "ℹ️ Nada que commitear"
git branch -M main || true

OWNER_FLAG=()
[ -n "$OWNER" ] && OWNER_FLAG=(--owner "$OWNER")

echo "📦 Creando repo '$REPO_NAME' ($VISIBILITY) y subiendo…"
if ! gh repo create "$REPO_NAME" "${OWNER_FLAG[@]}" --"$VISIBILITY" --source=. --remote=origin --push -y; then
  echo "ℹ️ Repositorio puede existir. Configurando 'origin' y push…"
  [ -z "$OWNER" ] && OWNER="$(gh api user -q .login)"
  git remote remove origin >/dev/null 2>&1 || true
  git remote add origin "https://github.com/$OWNER/$REPO_NAME.git"
  git push -u origin main
fi

ORIGIN_URL="$(git config --get remote.origin.url)"
REPO_SLUG="$(basename -s .git "$ORIGIN_URL")"
OWNER_LOGIN="$(printf "%s" "$ORIGIN_URL" | sed -E 's#.*github.com[:/]+([^/]+)/.*#\1#')"

echo "🌐 Activando GitHub Pages…"
gh api -X POST "repos/$OWNER_LOGIN/$REPO_SLUG/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 || gh api -X PUT  "repos/$OWNER_LOGIN/$REPO_SLUG/pages" -f "source[branch]=main" -f "source[path]=/"

PAGES_URL="https://$OWNER_LOGIN.github.io/$REPO_SLUG/"
echo "✅ Publicado: $PAGES_URL"
if command -v xdg-open >/dev/null 2>&1; then xdg-open "$PAGES_URL" >/dev/null 2>&1 || true
elif command -v open >/dev/null 2>&1; then open "$PAGES_URL" >/dev/null 2>&1 || true; fi
