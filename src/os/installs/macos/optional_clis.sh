#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" \
    && . "../../utils.sh" \
    && . "./utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Optional CLIs that are not Homebrew formulae. A failed installer
# does not stop the rest of setup. cursor-agent and Claude Code land
# on ~/.local/bin. Bun lands on ~/.bun/bin. bash_exports prepends
# each directory once.

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
    # The official installer may also append ~/.local/bin to a shell
    # rc file. bash_exports still adds that directory only once.
    install_optional_cli \
        "Claude Code" \
        "claude" \
        "curl -fsSL https://claude.ai/install.sh | bash"

    # Bun 1.3.x via the official installer (latest 1.3 patch). Current
    # upstream is 1.4, which this machine does not use. SHELL=/bin/sh
    # makes the installer skip bash rc edits: those files are symlinks
    # into this repo. ~/.bun/bin is prepended from bash_exports.
    # https://bun.sh/docs/installation
    if cmd_exists "bun" || [ -x "${HOME}/.bun/bin/bun" ]; then
        print_success "Bun"
    else
        execute \
            "curl -fsSL https://bun.sh/install | env SHELL=/bin/sh bash -s bun-v1.3.14" \
            "Bun 1.3 (optional)" \
            || true
    fi

}

main
