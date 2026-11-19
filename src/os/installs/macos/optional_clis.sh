#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" \
    && . "../../utils.sh" \
    && . "./utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Optional CLIs that are not Homebrew formulae. A failed installer
# does not stop the rest of setup. Both land on ~/.local/bin, which
# bash_exports prepends once.

install_optional_cli() {

    local readable_name="$1"
    local binary="$2"
    local install_cmd="$3"

    if cmd_exists "$binary"; then
        print_success "$readable_name"
        return 0
    fi

    execute \
        "$install_cmd" \
        "$readable_name (optional)" \
        || true

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

main() {

    print_in_purple "\n   Optional CLIs\n\n"

    # https://cursor.com/docs/cli/overview
    install_optional_cli \
        "Cursor agent" \
        "cursor-agent" \
        "curl https://cursor.com/install -fsS | bash"

    # https://code.claude.com/docs/en/setup
    install_optional_cli \
        "Claude Code" \
        "claude" \
        "curl -fsSL https://claude.ai/install.sh | bash"

}

main
