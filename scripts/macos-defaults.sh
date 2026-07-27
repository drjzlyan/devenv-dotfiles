#!/usr/bin/env bash
# Apply conservative macOS defaults for development.
# Run manually; not part of the standard install.

set -euo pipefail

log() {
  printf '[macos-defaults] %s\n' "$*"
}

log "Fast key repeat"
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

log "Show hidden files in Finder"
defaults write com.apple.finder AppleShowAllFiles -bool true

log "Show path bar in Finder"
defaults write com.apple.finder ShowPathbar -bool true

log "Avoid creating .DS_Store on network volumes"
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

log "Restarting Finder..."
killall Finder || true

log "Done."
