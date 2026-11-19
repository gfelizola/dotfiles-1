#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" \
    && . "../../utils.sh" \
    && . "./utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print_in_purple "\n   Miscellaneous\n\n"

brew_install "Rectangle" "rectangle" "--cask"
brew_install "Unarchiver" "the-unarchiver" "--cask"
brew_install "VLC" "vlc" "--cask"

# Google Drive is installed as an app. Keep the cask.
brew_install "Google Drive" "google-drive" "--cask"

brew_install "Raycast" "raycast" "--cask"
brew_install "GrandPerspective" "grandperspective" "--cask"
brew_install "QLMarkdown" "qlmarkdown" "--cask"
brew_install "WhatsApp" "whatsapp" "--cask"
brew_install "Claude" "claude" "--cask"
brew_install "ChatGPT" "chatgpt" "--cask"
brew_install "Figma" "figma" "--cask"
brew_install "ClickUp" "clickup" "--cask"
brew_install "BetterDisplay" "betterdisplay" "--cask"
brew_install "Zoom" "zoom" "--cask"
brew_install "Tunnelblick" "tunnelblick" "--cask"
