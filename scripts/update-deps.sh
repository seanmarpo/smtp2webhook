#!/usr/bin/env bash
#
# update-deps.sh — Bump all dependencies to their latest versions,
# verify the build, and optionally increment the app's patch version
# and push to GitHub with a version tag.
#
# The version is only bumped if dependencies actually changed.
#
# Changes are measured against the last commit (HEAD), not the working tree,
# so the script is safe to re-run: if an upgrade breaks the build, fix the
# code and run it again. It picks up where it left off, does not bump the
# version twice, and includes your source fixes in the release commit.
#
# Usage:
#   ./update-deps.sh
#
# Prerequisites:
#   - cargo-edit (provides `cargo upgrade` and `cargo set-version`)
#     Install with: cargo install cargo-edit

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "%b[INFO]%b  %s\n" "$CYAN" "$RESET" "$*"; }
ok()    { printf "%b[OK]%b    %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%b[WARN]%b  %s\n" "$YELLOW" "$RESET" "$*"; }
error() { printf "%b[ERROR]%b %s\n" "$RED" "$RESET" "$*"; }
step()  { printf "\n%b── Step %s ──%b\n" "$BOLD" "$1" "$RESET"; }

# Read the package version from a Cargo.toml-formatted file.
read_version() { grep '^version' "$1" | head -1 | sed 's/.*"\(.*\)".*/\1/'; }

# Explain how to recover after a failed build/test, then exit.
fail_with_recovery() {
    error "$1"
    printf "\n"
    info "Your dependency upgrades are kept in Cargo.toml and Cargo.lock."
    info "Next steps:"
    info "  1. Fix the errors above (often an API change in an upgraded crate;"
    info "     check that crate's CHANGELOG)."
    info "  2. Re-run this script. It will continue from here and include"
    info "     your source fixes in the release commit."
    info "To abandon the upgrade instead:"
    info "  git checkout -- Cargo.toml Cargo.lock"
    exit 1
}

# ---------------------------------------------------------------------------
# Ensure we're in the project root (where Cargo.toml lives) inside git
# ---------------------------------------------------------------------------
if [[ ! -f Cargo.toml ]]; then
    error "Cargo.toml not found. Run this script from the project root."
    exit 1
fi

if ! git rev-parse --verify -q HEAD &>/dev/null; then
    error "This script must run inside a git repository with at least one commit."
    exit 1
fi

# ---------------------------------------------------------------------------
# Prerequisites: check for cargo-edit
# ---------------------------------------------------------------------------
if ! cargo upgrade --version &>/dev/null; then
    error "cargo-edit is not installed (needed for 'cargo upgrade' and 'cargo set-version')."
    info  "Install it with:  cargo install cargo-edit"
    exit 1
fi

# ---------------------------------------------------------------------------
# Baseline: the committed Cargo.toml / Cargo.lock at HEAD. Comparing against
# HEAD (rather than the working tree) means a previous, interrupted run's
# upgrades are still detected as changes when the script is re-run.
# ---------------------------------------------------------------------------
TOML_BEFORE=$(mktemp)
LOCK_BEFORE=$(mktemp)
trap 'rm -f "$TOML_BEFORE" "$LOCK_BEFORE"' EXIT
git show HEAD:Cargo.toml > "$TOML_BEFORE"
git show HEAD:Cargo.lock > "$LOCK_BEFORE" 2>/dev/null || : > "$LOCK_BEFORE"

OLD_VERSION=$(read_version "$TOML_BEFORE")
info "Current app version (HEAD): ${OLD_VERSION}"

if ! git diff --quiet HEAD -- Cargo.toml Cargo.lock; then
    warn "Cargo.toml/Cargo.lock already have uncommitted changes (probably from"
    warn "a previous run). Continuing from where it left off."
fi

# ---------------------------------------------------------------------------
step "1 — Check for outdated dependencies (dry-run)"
# ---------------------------------------------------------------------------
cargo update --dry-run 2>&1 || true

# ---------------------------------------------------------------------------
step "2 — Upgrade version constraints in Cargo.toml"
# ---------------------------------------------------------------------------
if ! cargo upgrade --incompatible; then
    error "'cargo upgrade' failed. See the output above."
    exit 1
fi
info "Cargo.toml diff vs HEAD:"
diff --unified=0 "$TOML_BEFORE" Cargo.toml || true

# ---------------------------------------------------------------------------
step "3 — Update Cargo.lock"
# ---------------------------------------------------------------------------
if ! cargo update; then
    error "'cargo update' failed. See the output above."
    exit 1
fi

# ---------------------------------------------------------------------------
# Detect whether anything actually changed (vs HEAD)
# ---------------------------------------------------------------------------
if diff -q "$TOML_BEFORE" Cargo.toml &>/dev/null \
    && diff -q "$LOCK_BEFORE" Cargo.lock &>/dev/null; then
    ok "All dependencies are already up to date. Nothing to do."
    exit 0
fi

# ---------------------------------------------------------------------------
step "4 — Verify build and tests"
# ---------------------------------------------------------------------------
info "Running cargo build …"
if ! cargo build; then
    fail_with_recovery "Build failed after dependency upgrade."
fi
ok "Build succeeded."

info "Running cargo test …"
if ! cargo test; then
    fail_with_recovery "Tests failed after dependency upgrade."
fi
ok "Tests passed."

# ---------------------------------------------------------------------------
step "5 — Bump app patch version"
# ---------------------------------------------------------------------------
CURRENT_VERSION=$(read_version Cargo.toml)
if [[ "$CURRENT_VERSION" != "$OLD_VERSION" ]]; then
    info "Version already bumped since HEAD (${OLD_VERSION} → ${CURRENT_VERSION}); not bumping again."
else
    cargo set-version --bump patch
fi
NEW_VERSION=$(read_version Cargo.toml)
ok "Version: ${OLD_VERSION} → ${NEW_VERSION}"

TAG="v${NEW_VERSION}"
if git rev-parse -q --verify "refs/tags/${TAG}" &>/dev/null; then
    error "Tag ${TAG} already exists. Set a different version with:"
    info  "  cargo set-version <version>"
    info  "then re-run this script."
    exit 1
fi

# ---------------------------------------------------------------------------
step "6 — Confirm release build"
# ---------------------------------------------------------------------------
info "Running cargo build --release …"
if ! cargo build --release; then
    fail_with_recovery "Release build failed."
fi
ok "Release build succeeded."

# ---------------------------------------------------------------------------
step "7 — Summary"
# ---------------------------------------------------------------------------
printf "\n"
info "Cargo.toml dependency changes:"
{ diff --unified=0 "$TOML_BEFORE" Cargo.toml || true; } | grep '^[+-]' | grep -v '^[+-][+-][+-]' | grep -v '^[+-]version' || echo "  (no direct dependency version changes — only Cargo.lock transitive deps updated)"
printf "\n"

# Source/other tracked files changed besides Cargo.toml/Cargo.lock
# (e.g. code fixes for breaking API changes in upgraded crates).
OTHER_CHANGES=$(git diff --name-only HEAD -- . ':(exclude)Cargo.toml' ':(exclude)Cargo.lock')
if [[ -n "$OTHER_CHANGES" ]]; then
    info "Other modified tracked files (will be included in the commit):"
    printf '  %s\n' $OTHER_CHANGES
fi

UNTRACKED=$(git ls-files --others --exclude-standard)
if [[ -n "$UNTRACKED" ]]; then
    warn "Untracked files will NOT be committed (git add them first if needed):"
    printf '  %s\n' $UNTRACKED
fi
printf "\n"
ok "App version: ${OLD_VERSION} → ${NEW_VERSION}"

# ---------------------------------------------------------------------------
step "8 — Push to GitHub"
# ---------------------------------------------------------------------------
printf "\n"
info "The following will be committed, tagged, and pushed:"
info "  - Cargo.toml and Cargo.lock changes"
[[ -n "$OTHER_CHANGES" ]] && info "  - Other modified tracked files listed above"
info "  - Tag: ${TAG}"
printf "\n"

read -rp "Commit, tag, and push to GitHub? [y/N] " REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    git add -u
    git commit -m "deps: upgrade dependencies → ${TAG}"
    git tag -a "$TAG" -m "Release ${TAG}"
    git push
    git push origin "$TAG"
    printf "\n"
    ok "Pushed commit and tag ${TAG} to GitHub."
else
    warn "Skipped. You can manually commit and push when ready:"
    info "  git add -u"
    info "  git commit -m \"deps: upgrade dependencies → ${TAG}\""
    info "  git tag -a ${TAG} -m \"Release ${TAG}\""
    info "  git push && git push origin ${TAG}"
fi

printf "\n%b%bAll done!%b\n" "$GREEN" "$BOLD" "$RESET"
