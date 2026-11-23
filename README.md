# [GFELIZOLA][repo]’s dotfiles

[![CI status for macOS][ci badge macos]][ci link macos]
[![CI status for Ubuntu][ci badge ubuntu]][ci link ubuntu]

These are the base dotfiles that I start with when I set up
a new environment (for more specific local needs I use the
[`*.local`](#local-settings) files).

## Table of Contents

* [🔧 Setup](#setup)
* [📸 Screenshots](#screenshots)
  * [🔁 Git](#git)
  * [⌨️  Vim](#vim)
* [💄 Customize](#customize)
  * [🔀 Forks](#forks)
  * [🌐 Local Settings](#local-settings)
    * [🐚 `~/.bash.local`](#bashlocal)
    * [🔁 `~/.gitconfig.local`](#gitconfiglocal)
    * [⌨️  `~/.vimrc.local`](#vimrclocal)
* [↕️  Update](#update)
* [🔐 Env backups](#env-backups)
* [📑 License](#license)

## Setup

To set up the dotfiles run the appropriate snippet in the terminal:

> [!CAUTION]
> __DO NOT__ run the setup script if you do not fully understand
> [what it does][setup]. Seriously, __DON'T__!

| OS | Snippet |
|:---|:---|
| macOS | `bash -c "$(curl -LsS https://raw.github.com/gfelizola/dotfiles-1/main/src/os/setup.sh)"` |
| Ubuntu | `bash -c "$(wget -qO - https://raw.github.com/gfelizola/dotfiles-1/main/src/os/setup.sh)"` |

That's it! ✨

The setup process will:

* Download the dotfiles on your computer
  (by default it will suggest `~/projects/dotfiles`).
* [Symlink][symlink] the [Git], [shell], [tmux],
  and [Vim] related files.
* Install applications / command-line tools for
  [macOS][install macos] / [Ubuntu][install ubuntu].
* Set custom [macOS][preferences macos] /
  [Ubuntu][preferences ubuntu] preferences.
* Install the [Vim][vim plugins] and
  [VS Code][vscode plugins] plugins.

Setup process in action:

<!-- markdownlint-disable MD033 -->
| <video src="https://user-images.githubusercontent.com/1223565/236653425-5beae04a-39e3-4f29-8113-009e402818e6.mp4" title="Setup process on macOS"/> |<video src="https://user-images.githubusercontent.com/1223565/236653424-1702c359-1b68-4815-b3cc-96f6665c5e88.mp4" title="Setup process on Ubuntu"/> |
|:---:|:---:|
<!-- markdownlint-enable MD033 -->

## Screenshots

### Git

Output for `git status`:

| ![Output for Git status on macOS][git output macos] | ![Output for Git status on Ubuntu][git output ubuntu] |
|:---:|:---:|
| macOS | Ubuntu |

Output for `git log`:

| ![Output for Git log on macOS][git log macos] | ![Output for Git log on Ubuntu][git log ubuntu] |
|:---:|:---:|
| macOS | Ubuntu |

### Vim

| ![Vim on macOS][vim macos] | ![Vim on Ubuntu][vim ubuntu] |
|:---:|:---:|
| macOS | Ubuntu |

## Customize

### Local Settings

The dotfiles can be easily extended to suit additional local
requirements by using the following files:

#### `~/.bash.local`

The `~/.bash.local` file will be automatically sourced after all
the other [Bash related files][shell], thus, allowing its content
to add to or overwrite the existing aliases, settings, `PATH`, etc.

Here is an example:

```shell
#!/bin/bash

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Set PATH additions.

PATH="/Users/alrra/projects/dotfiles/src/bin/:$PATH"

export PATH

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Set local aliases.

alias g="git"
```

#### `~/.gitconfig.local`

[`src/git/gitconfig`](src/git/gitconfig) ends with
`include.path = ~/.gitconfig.local`. Setup creates that file from
[`create_local_config_files.sh`](src/os/create_local_config_files.sh)
when it is missing. It is not committed. Local settings load after
the shared ones, so they can add to or override them.

The committed Git config is portable personal config only. Put
machine-specific settings in `~/.gitconfig.local`:

* `user.name` and `user.email` (`user.useConfigOnly` is on, and no
  global identity is stored in the repository)
* `[safe] directory` entries, including a self-hosted GitHub Actions
  runner checkout
* `http.postBuffer` and `http.version`
* a `credential.helper` that points at a local binary, such as
  `~/.local/bin/origin`

Per-folder identities use `includeIf "gitdir:"`. The template has
commented examples for a personal GitHub identity and a work Trino
identity. Fill those in on the machine. Do not commit real addresses.

```gitconfig
[user]

    name = Your Name
    email = personal@example.com

# Work checkouts (Trino). The included file holds that identity.
# [includeIf "gitdir:~/projects/trino/"]
#     path = ~/.gitconfig.work
```

#### `~/.vimrc.local`

The `~/.vimrc.local` file will be automatically sourced after
`~/.vimrc`, thus, allowing its content to add or overwrite the
settings from `~/.vimrc`.

Here is an example:

```vim
" Disable arrow keys in insert mode.

inoremap <Down>  <ESC>:echoe "Use j"<CR>
inoremap <Left>  <ESC>:echoe "Use h"<CR>
inoremap <Right> <ESC>:echoe "Use l"<CR>
inoremap <Up>    <ESC>:echoe "Use k"<CR>

" Disable arrow keys in normal mode.

nnoremap <Down>  :echoe "Use j"<CR>
nnoremap <Left>  :echoe "Use h"<CR>
nnoremap <Right> :echoe "Use l"<CR>
nnoremap <Up>    :echoe "Use k"<CR>
```

### Forks

If you decide to [fork] this project, do not forget to substitute
my username with your own in the [setup snippets](#setup) and [in
the setup script][setup script].

## Update

To update the dotfiles you can either run the [setup script][setup]
or, if you want to update one particular part, run the appropriate
[os script](src/os).

## Env backups

`env-backup` encrypts secret env files from `~/projects` and, when
it is mounted, `/Volumes/ADATA-GFELIZOLA/projects`. Snapshots go to
Google Drive (`My Drive/Backups/dotenv` for
`gfelizola@gmail.com`). Override that folder with `ENV_BACKUP_DIR`.

Encryption uses [age] and only the public recipient, so the daily
job does not need the private key. The private key stays in the
macOS login keychain.

### Create a key

The macOS install step installs `age` and the LaunchAgent. Create
the key once:

```shell
env-backup setup
```

Put the printed identity in a password manager. Do not put it in
this repo or in Google Drive. The public recipient is recorded in
`~/.config/env-backup/recipient`.

Check what would be copied, then write a snapshot:

```shell
env-backup backup --dry-run
env-backup backup
env-backup status
```

On another Mac, install `age` and import the saved identity:

```shell
env-backup import-identity
env-backup restore
```

`env-backup export-identity` prints the key again. Do not redirect
it into the repo or into Drive.

### What is included

Any file whose name matches `.env*` or `.dev.vars` is included,
including names such as `.env.local`, `.env.fallback`,
`.env.evidence`, `.env.emulator`, and `.env.bkp`. Templates are
skipped: `*.example`, `*.sample`, `*.template`, and `*.dist`.
Directories such as `node_modules`, `.git`, `dist`, and `build`
are not walked. A `.env` that git already tracks is still backed
up. Extra patterns can be added in
`~/.config/env-backup/include-names`, `exclude-names`, and
`prune-dirs`.

Paths are stored relative to each root, under `home` or `adata`,
so the two trees do not collide. If the external disk is absent,
the job logs that and exits. It will not publish a snapshot that
drops files the last backup already had from that disk.

Unchanged content does not create a new snapshot. Retention keeps
the newest 3 snapshots, 14 distinct days, and 12 distinct months.

### Restore

```shell
env-backup list
env-backup show
env-backup diff
env-backup restore --dry-run
env-backup restore --path some/project
env-backup restore --force
```

A newer local file is left alone unless `--force` is passed.
Before an older file is replaced, the current copy is saved beside
it with an `.env-backup-bak-` suffix, which later backups ignore.

### Schedule

```shell
env-backup install-agent
env-backup uninstall-agent
```

The agent runs at 09:15, when any volume mounts, and when
`/Volumes/ADATA-GFELIZOLA` changes. It calls Homebrew bash when
that exists. Logs:

```text
~/Library/Logs/env-backup.log
~/Library/Logs/env-backup.err.log
```

If Google Drive or the ADATA disk is not there, the run exits 0
after one log line.

### Old Cryptomator vault

`env-push`, `env-pull`, and `env-status` are deprecated wrappers
around `env-backup`. If the old `/Volumes/DotEnvs` volume is
mounted, this previews a one-time copy back into the projects and
then performs it:

```shell
env-backup migrate
env-backup migrate --apply
```

### Test

```shell
./scripts/test/env-backup.sh
```

## License

The code is available under the [MIT license][license].

<!-- Link labels: -->

[ci badge macos]: https://github.com/alrra/dotfiles/workflows/macOS/badge.svg
[ci badge ubuntu]: https://github.com/alrra/dotfiles/workflows/Ubuntu/badge.svg
[ci link macos]: https://github.com/alrra/dotfiles/actions?query=workflow%3AmacOS
[ci link ubuntu]: https://github.com/alrra/dotfiles/actions?query=workflow%3AUbuntu
[fork]: https://help.github.com/en/github/getting-started-with-github/fork-a-repo
[git log macos]: https://user-images.githubusercontent.com/1223565/101947422-519fc580-3ba5-11eb-90bc-1438072a45e1.png
[git log ubuntu]: https://user-images.githubusercontent.com/1223565/101947420-51072f00-3ba5-11eb-9061-efb30ace1c21.png
[git output macos]: https://user-images.githubusercontent.com/1223565/101947419-51072f00-3ba5-11eb-9e8e-fea987ac97c2.png
[git output ubuntu]: https://user-images.githubusercontent.com/1223565/101947417-506e9880-3ba5-11eb-805c-0732602c34b3.png
[Git]: src/git
[install macos]: src/os/installs/macos
[install ubuntu]: src/os/installs/ubuntu
[license]: LICENSE.txt
[preferences macos]: src/os/preferences/macos
[preferences ubuntu]: src/os/preferences/ubuntu
[age]: https://github.com/FiloSottile/age
[repo]: https://github.com/alrra
[setup script]: https://github.com/alrra/dotfiles/blob/main/src/os/setup.sh#L3
[setup]: src/os/setup.sh
[shell]: src/shell
[symlink]: src/os/create_symbolic_links.sh
[tmux]: src/tmux
[vim macos]: https://user-images.githubusercontent.com/1223565/101947425-52385c00-3ba5-11eb-9a2a-13e7910d3673.png
[vim plugins]: src/vim/vim/pack/minpac/start
[vim ubuntu]: https://user-images.githubusercontent.com/1223565/101947424-519fc580-3ba5-11eb-83b1-e4c3573315a3.png
[Vim]: src/vim
[vscode plugins]: src/os/installs/macos/vscode.sh
