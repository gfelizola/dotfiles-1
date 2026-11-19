#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" \
    && . "../../utils.sh" \
    && . "./utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Version-controlled extension list. IDs are installed with
# `--install-extension` and are not pinned to a marketplace version.
# Cursor and VS Code keep separate extension directories, so each
# CLI that is on PATH receives the same list.

declare -a EDITOR_EXTENSIONS=(
    "biomejs.biome"
    "prisma.prisma"
    "dart-code.dart-code"
    "dart-code.flutter"
    "felixangelov.bloc"
    "eamodio.gitlens"
    "bradlc.vscode-tailwindcss"
    "usernamehw.errorlens"
    "mikestead.dotenv"
    "ms-azuretools.vscode-docker"
    "vscjava.vscode-gradle"
    "github.copilot"
    "github.copilot-chat"
)

install_extension() {

    execute \
        "$1 --install-extension $2" \
        "$1 extension ($2)"

}

install_editor_extensions() {

    local cli=""
    local extension_id=""
    local installed_any="false"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    for cli in cursor code; do

        if ! cmd_exists "$cli"; then
            continue
        fi

        installed_any="true"

        for extension_id in "${EDITOR_EXTENSIONS[@]}"; do
            install_extension "$cli" "$extension_id"
        done

    done

    if [ "$installed_any" != "true" ]; then
        print_warning "Neither 'cursor' nor 'code' is on PATH; skipped editor extensions"
    fi

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print_in_purple "\n   Visual Studio Code\n\n"

# Install VSCode
brew_install "Visual Studio Code" "visual-studio-code" "--cask"

printf "\n"

# `cursor` is installed from dev.sh. The shell command has to be on
# PATH (Cursor: Install 'cursor' command in PATH) before extensions
# can be installed for it.
install_editor_extensions

# Close the editors so the newly installed extensions are picked up.
osascript -e 'quit app "Visual Studio Code"' &> /dev/null \
    || true
osascript -e 'quit app "Cursor"' &> /dev/null \
    || true
