#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" \
    && . "../../utils.sh" \
    && . "./utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print_in_purple "\n   Development Tools\n\n"

# Formulae

brew_install "AWS CLI" "awscli"
brew_install "Biome" "biome"
brew_install "PHP 8.3" "php@8.3"
brew_install "Composer" "composer"
brew_install ".NET" "dotnet"
brew_install "MySQL" "mysql"
brew_install "libpq" "libpq"
brew_install "ripgrep" "ripgrep"
brew_install "Semgrep" "semgrep"
brew_install "Ruby" "ruby"
brew_install "Python 3.13" "python@3.13"
brew_install "uv" "uv"
brew_install "gitleaks" "gitleaks"
brew_install "Flutter Version Manager" "fvm" "" "leoafarias/fvm"

# Docker Desktop is the cask token `docker-desktop` (formerly `docker`).
# `docker-completion` is the formula the owner's `brew list` included.
# Desktop already ships completions; if Homebrew reports a conflict,
# the formula install fails and the rest of setup continues.

brew_install "Docker Desktop" "docker-desktop" "--cask"
brew_install "Docker Completion" "docker-completion"

# Casks. Postman was already installed from this file; Warp stays in
# bash.sh. Neither is repeated here.

brew_install "Postman" "postman" "--cask"
brew_install "Cursor" "cursor" "--cask"
brew_install "ngrok" "ngrok" "--cask"
brew_install "Google Cloud CLI" "gcloud-cli" "--cask"
brew_install "Redis Insight" "redis-insight" "--cask"
brew_install "Android Studio" "android-studio" "--cask"
brew_install "Beekeeper Studio" "beekeeper-studio" "--cask"
