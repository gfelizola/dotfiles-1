#!/usr/bin/env bash

# Library for `env-backup`. Source it; do not execute it.
#
# Bash 3.2 compatible so the LaunchAgent can fall back to /bin/bash.
# Homebrew bash is still preferred in the plist.
#
# Extend matching without code changes via:
#   ~/.config/env-backup/include-names   extra basename globs
#   ~/.config/env-backup/exclude-names   extra basename globs
#   ~/.config/env-backup/prune-dirs      extra directory names to skip
#   ~/.config/env-backup/roots           lines of name|/absolute/path
# Or edit the default arrays in env_backup_reset_patterns.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    printf '%s\n' "env-backup-lib.sh is a library. Run env-backup instead." >&2
    exit 1
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

env_backup_configure() {

    ENV_BACKUP_CONFIG_DIR="${ENV_BACKUP_CONFIG_DIR:-$HOME/.config/env-backup}"
    ENV_BACKUP_DIR="${ENV_BACKUP_DIR:-$HOME/Library/CloudStorage/GoogleDrive-gfelizola@gmail.com/My Drive/Backups/dotenv}"
    ENV_BACKUP_VAULT="${ENV_BACKUP_VAULT:-/Volumes/DotEnvs}"
    ENV_BACKUP_KEYCHAIN_SERVICE="${ENV_BACKUP_KEYCHAIN_SERVICE:-com.gfelizola.env-backup.age-identity}"
    ENV_BACKUP_AGENT_LABEL="${ENV_BACKUP_AGENT_LABEL:-com.gfelizola.env-backup}"
    ENV_BACKUP_KEEP_RECENT="${ENV_BACKUP_KEEP_RECENT:-3}"
    ENV_BACKUP_KEEP_DAILY="${ENV_BACKUP_KEEP_DAILY:-14}"
    ENV_BACKUP_KEEP_MONTHLY="${ENV_BACKUP_KEEP_MONTHLY:-12}"

    env_backup_require_count "$ENV_BACKUP_KEEP_RECENT" "ENV_BACKUP_KEEP_RECENT"
    env_backup_require_count "$ENV_BACKUP_KEEP_DAILY" "ENV_BACKUP_KEEP_DAILY"
    env_backup_require_count "$ENV_BACKUP_KEEP_MONTHLY" "ENV_BACKUP_KEEP_MONTHLY"

    env_backup_reset_patterns
    env_backup_load_roots

}

env_backup_require_count() {

    case "$1" in
        ""|*[!0-9]*)
            env_backup_die "$2 must be a non-negative integer"
            ;;
    esac

}

env_backup_reset_patterns() {

    PRUNE_DIR_NAMES=(
        node_modules
        .git
        .hg
        .svn
        dist
        build
        out
        target
        coverage
        .next
        .nuxt
        .output
        .turbo
        .cache
        .parcel-cache
        .svelte-kit
        vendor
        bower_components
        Pods
        DerivedData
        .venv
        venv
        __pycache__
        .gradle
        .yarn
        tmp
        .tmp
    )

    # Broad .env* match, plus other real secret filenames that do not
    # start with .env. Templates are removed by the exclude list.
    INCLUDE_NAME_PATTERNS=(
        ".env*"
        ".dev.vars"
        ".dev.vars.*"
    )

    EXCLUDE_NAME_PATTERNS=(
        "*.example"
        "*.example.*"
        "*.sample"
        "*.sample.*"
        "*.template"
        "*.template.*"
        "*.dist"
        "*.dist.*"
        "*.env-backup-bak"
        "*.env-backup-bak-*"
    )

    env_backup_append_pattern_file "$ENV_BACKUP_CONFIG_DIR/prune-dirs" prune
    env_backup_append_pattern_file "$ENV_BACKUP_CONFIG_DIR/include-names" include
    env_backup_append_pattern_file "$ENV_BACKUP_CONFIG_DIR/exclude-names" exclude

}

env_backup_append_pattern_file() {

    local file="$1"
    local kind="$2"
    local line=""

    [ -f "$file" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ""|\#*)
                continue
                ;;
        esac

        case "$kind" in
            prune)
                PRUNE_DIR_NAMES[${#PRUNE_DIR_NAMES[@]}]="$line"
                ;;
            include)
                INCLUDE_NAME_PATTERNS[${#INCLUDE_NAME_PATTERNS[@]}]="$line"
                ;;
            exclude)
                EXCLUDE_NAME_PATTERNS[${#EXCLUDE_NAME_PATTERNS[@]}]="$line"
                ;;
        esac
    done < "$file"

}

env_backup_default_roots() {

    printf '%s|%s\n' "home" "$HOME/projects"
    printf '%s|%s\n' "adata" "/Volumes/ADATA-GFELIZOLA/projects"

}

env_backup_load_roots() {

    local spec=""
    local line=""
    local name=""
    local path=""

    ROOT_NAMES=()
    ROOT_PATHS=()

    if [ -n "${ENV_BACKUP_ROOTS+x}" ]; then
        spec="$ENV_BACKUP_ROOTS"
    elif [ -f "$ENV_BACKUP_CONFIG_DIR/roots" ]; then
        spec=$(cat "$ENV_BACKUP_CONFIG_DIR/roots")
    else
        spec=$(env_backup_default_roots)
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ""|\#*)
                continue
                ;;
        esac

        name=${line%%|*}
        path=${line#*|}

        case "$name" in
            ""|*[!A-Za-z0-9_-]*)
                env_backup_die "invalid root name: $name"
                ;;
        esac

        [ -n "$path" ] || env_backup_die "root $name has an empty path"

        # shellcheck disable=SC2088
        case "$path" in
            "~")
                path="$HOME"
                ;;
            "~/"*)
                path="$HOME/${path#"~/"}"
                ;;
        esac

        ROOT_NAMES[${#ROOT_NAMES[@]}]="$name"
        ROOT_PATHS[${#ROOT_PATHS[@]}]="$path"
    done << EOF
$spec
EOF

    [ "${#ROOT_NAMES[@]}" -gt 0 ] || env_backup_die "no backup roots configured"

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

env_backup_die() {

    printf 'env-backup: %s\n' "$*" >&2
    exit 1

}

env_backup_log() {

    local line=""
    local dest=""

    line="$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*"
    printf '%s\n' "$line"

    if [ "${ENV_BACKUP_LOG_FILE:-}" = "-" ]; then
        return 0
    fi

    if [ -n "${ENV_BACKUP_LOG_FILE:-}" ]; then
        dest="$ENV_BACKUP_LOG_FILE"
    elif [ -t 1 ]; then
        dest="$HOME/Library/Logs/env-backup.log"
    else
        return 0
    fi

    command mkdir -p -- "$(env_backup_dirname "$dest")" 2> /dev/null || return 0
    printf '%s\n' "$line" >> "$dest"

}

env_backup_dirname() {

    case "$1" in
        */*)
            printf '%s\n' "${1%/*}"
            ;;
        *)
            printf '%s\n' "."
            ;;
    esac

}

env_backup_basename() {

    printf '%s\n' "${1##*/}"

}

env_backup_ensure_config_dir() {

    command mkdir -p -- "$ENV_BACKUP_CONFIG_DIR"
    command chmod 700 "$ENV_BACKUP_CONFIG_DIR"

}

env_backup_mktmp() {

    local dir=""

    dir=$(mktemp -d "${TMPDIR:-/tmp}/env-backup.XXXXXX")
    command chmod 700 "$dir"

    # Record the directory in a file. Callers use this function inside
    # command substitutions, so a shell variable would not survive.
    if [ -n "${ENV_BACKUP_TMP_REGISTRY:-}" ]; then
        printf '%s\n' "$dir" >> "$ENV_BACKUP_TMP_REGISTRY"
    fi

    printf '%s\n' "$dir"

}

env_backup_cleanup() {

    local dir=""
    local tmp_root=""

    tmp_root="${TMPDIR:-/tmp}"

    if [ -n "${ENV_BACKUP_TMP_REGISTRY:-}" ] && [ -f "$ENV_BACKUP_TMP_REGISTRY" ]; then
        while IFS= read -r dir || [ -n "$dir" ]; do
            [ -n "$dir" ] || continue
            case "$dir" in
                "$tmp_root"/env-backup.*)
                    command rm -rf -- "$dir"
                    ;;
            esac
        done < "$ENV_BACKUP_TMP_REGISTRY"
        command rm -f -- "$ENV_BACKUP_TMP_REGISTRY"
        ENV_BACKUP_TMP_REGISTRY=""
    fi

    if [ -n "${ENV_BACKUP_PARTIAL:-}" ] && [ -f "$ENV_BACKUP_PARTIAL" ]; then
        command rm -f -- "$ENV_BACKUP_PARTIAL"
        ENV_BACKUP_PARTIAL=""
    fi

    if [ "${ENV_BACKUP_LOCK_HELD:-0}" = "1" ]; then
        command rm -rf -- "$ENV_BACKUP_CONFIG_DIR/lock"
        ENV_BACKUP_LOCK_HELD=0
    fi

}

env_backup_lock() {

    local dir=""
    local pid=""

    env_backup_ensure_config_dir
    dir="$ENV_BACKUP_CONFIG_DIR/lock"

    if command mkdir -- "$dir" 2> /dev/null; then
        printf '%s\n' "$$" > "$dir/pid"
        ENV_BACKUP_LOCK_HELD=1
        return 0
    fi

    if [ -f "$dir/pid" ]; then
        pid=$(cat "$dir/pid" 2> /dev/null || true)
    fi

    if [ -n "$pid" ] && ! kill -0 "$pid" 2> /dev/null; then
        command rm -rf -- "$dir"
        command mkdir -- "$dir"
        printf '%s\n' "$$" > "$dir/pid"
        ENV_BACKUP_LOCK_HELD=1
        return 0
    fi

    env_backup_log "another env-backup is already running${pid:+ (pid $pid)}; leaving it alone"
    exit 0

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

env_backup_sha256_stdin() {

    if command -v sha256sum > /dev/null 2>&1; then
        sha256sum | awk '{ print $1 }'
    else
        shasum -a 256 | awk '{ print $1 }'
    fi

}

env_backup_sha256_file() {

    if command -v sha256sum > /dev/null 2>&1; then
        sha256sum -- "$1" | awk '{ print $1 }'
    else
        shasum -a 256 "$1" | awk '{ print $1 }'
    fi

}

env_backup_detect_stat() {

    if [ -n "${ENV_BACKUP_STAT_KIND:-}" ]; then
        return 0
    fi

    if stat -c %Y / > /dev/null 2>&1; then
        ENV_BACKUP_STAT_KIND="gnu"
    else
        ENV_BACKUP_STAT_KIND="bsd"
    fi

}

env_backup_mtime() {

    env_backup_detect_stat

    if [ "$ENV_BACKUP_STAT_KIND" = "gnu" ]; then
        stat -c %Y -- "$1"
    else
        stat -f %m "$1"
    fi

}

env_backup_touch_mtime() {

    local epoch="$1"
    local file="$2"
    local fmt=""

    if touch -d "@$epoch" "$file" 2> /dev/null; then
        return 0
    fi

    if date -r "$epoch" +%Y%m%d%H%M.%S > /dev/null 2>&1; then
        fmt=$(date -r "$epoch" +%Y%m%d%H%M.%S)
    else
        fmt=$(date -u -d "@$epoch" +%Y%m%d%H%M.%S)
    fi

    touch -t "$fmt" "$file"

}

env_backup_now_stamp() {

    if [ -n "${ENV_BACKUP_NOW:-}" ]; then
        printf '%s\n' "$ENV_BACKUP_NOW"
        return 0
    fi

    date -u +"%Y%m%dT%H%M%SZ"

}

env_backup_format_stamp() {

    local stamp="$1"

    printf '%s-%s-%s %s:%s:%s UTC\n' \
        "${stamp:0:4}" "${stamp:4:2}" "${stamp:6:2}" \
        "${stamp:9:2}" "${stamp:11:2}" "${stamp:13:2}"

}

env_backup_snapshot_stamp() {

    local base=""

    base=$(env_backup_basename "$1")
    base=${base#dotenv-}
    base=${base%.age}
    base=${base%.partial}
    printf '%s\n' "$base"

}

env_backup_valid_snapshot_name() {

    case "$1" in
        dotenv-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z.age)
            return 0
            ;;
    esac

    return 1

}

env_backup_name_included() {

    local base="$1"
    local pat=""
    local matched=1

    for pat in "${INCLUDE_NAME_PATTERNS[@]}"; do
        # shellcheck disable=SC2254
        case "$base" in
            $pat)
                matched=0
                ;;
        esac
    done

    [ "$matched" -eq 0 ] || return 1

    for pat in "${EXCLUDE_NAME_PATTERNS[@]}"; do
        # shellcheck disable=SC2254
        case "$base" in
            $pat)
                return 1
                ;;
        esac
    done

    return 0

}

env_backup_scan_root() {

    local namespace="$1"
    local root="$2"
    local outfile="$3"
    local -a find_args=()
    local name=""
    local first=1
    local path=""
    local base=""
    local rel=""

    find_args=("$root" "(")

    for name in "${PRUNE_DIR_NAMES[@]}"; do
        if [ "$first" -eq 0 ]; then
            find_args+=("-o")
        fi
        first=0
        find_args+=("-name" "$name")
    done

    find_args+=(")" "-prune" "-o" "-print0")

    while IFS= read -r -d '' path; do
        [ -f "$path" ] || continue
        [ "$path" = "$root" ] && continue

        base=${path##*/}
        env_backup_name_included "$base" || continue

        rel=${path#"$root"/}

        case "$rel" in
            /*|..|../*|*/..|*/../*|*$'\t'*|*$'\n'*)
                env_backup_log "skipping unsafe path under $namespace: $rel"
                continue
                ;;
        esac

        printf '%s\t%s\t%s\n' "$namespace" "$rel" "$path" >> "$outfile"
    done < <(find "${find_args[@]}" 2> /dev/null || true)

}

env_backup_build_manifest() {

    local list="$1"
    local manifest="$2"
    local sorted=""
    local namespace=""
    local rel=""
    local path=""
    local hash=""
    local mtime=""

    sorted="$(env_backup_mktmp)/sorted.tsv"
    LC_ALL=C sort -t "$(printf '\t')" -k1,1 -k2,2 "$list" > "$sorted"

    : > "$manifest.body"

    while IFS="$(printf '\t')" read -r namespace rel path; do
        [ -n "${namespace:-}" ] || continue
        [ -f "$path" ] || env_backup_die "disappeared while scanning: $path"

        hash=$(env_backup_sha256_file "$path") || env_backup_die "could not hash $path"
        mtime=$(env_backup_mtime "$path") || env_backup_die "could not stat $path"

        printf '%s\t%s\t%s\t%s\n' "$namespace" "$rel" "$hash" "$mtime" >> "$manifest.body"
    done < "$sorted"

    {
        printf '%s\n' "# env-backup-manifest v1"
        printf '%s\n' "# namespace	path	sha256	mtime"
        if [ -s "$manifest.body" ]; then
            cat "$manifest.body"
        fi
    } > "$manifest"

    command rm -f -- "$manifest.body"

}

env_backup_manifest_hash() {

    local manifest="$1"

    if [ ! -s "$manifest" ]; then
        env_backup_sha256_stdin < /dev/null
        return 0
    fi

    awk -F '\t' '
        /^#/ { next }
        NF >= 3 { print $1 "\t" $2 "\t" $3 }
    ' "$manifest" | env_backup_sha256_stdin

}

env_backup_line_count() {

    local n=0

    if [ ! -f "$1" ]; then
        printf '%s\n' "0"
        return 0
    fi

    n=$(wc -l < "$1" | tr -d ' ')
    printf '%s\n' "$n"

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

env_backup_destination_parent_ok() {

    local rest=""
    local provider=""
    local account=""

    case "$ENV_BACKUP_DIR" in
        "$HOME/Library/CloudStorage/"*)
            rest=${ENV_BACKUP_DIR#"$HOME/Library/CloudStorage/"}
            provider=${rest%%/*}

            if [ -z "$provider" ] || [ "$provider" = "$rest" ]; then
                return 1
            fi

            account="$HOME/Library/CloudStorage/$provider"

            if [ ! -d "$account" ]; then
                return 1
            fi

            case "$rest" in
                "My Drive"|"My Drive"/*|*/"My Drive"|*/"My Drive"/*)
                    [ -d "$account/My Drive" ] || return 1
                    ;;
            esac
            ;;
    esac

    return 0

}

env_backup_destination_ready() {

    local create="${1:-1}"

    if [ -d "$ENV_BACKUP_DIR" ]; then
        return 0
    fi

    env_backup_destination_parent_ok || return 1

    if [ "$create" -eq 1 ]; then
        command mkdir -p -- "$ENV_BACKUP_DIR"
        command chmod 700 "$ENV_BACKUP_DIR" 2> /dev/null || true
    fi

    return 0

}

env_backup_load_state() {

    local file=""
    local key=""
    local a=""
    local b=""
    local c=""

    STATE_SNAPSHOT=""
    STATE_HASH=""
    STATE_CREATED=""
    STATE_FILES="0"
    STATE_PARTIAL="0"
    STATE_ROOT_NAMES=()
    STATE_ROOT_PRESENT=()
    STATE_ROOT_COUNTS=()

    file="$ENV_BACKUP_DIR/state"
    [ -f "$file" ] || return 1

    while read -r key a b c; do
        case "$key" in
            ""|\#*)
                continue
                ;;
            version)
                ;;
            snapshot)
                STATE_SNAPSHOT="$a"
                ;;
            hash)
                STATE_HASH="$a"
                ;;
            created)
                STATE_CREATED="$a"
                ;;
            files)
                STATE_FILES="$a"
                ;;
            partial)
                STATE_PARTIAL="$a"
                ;;
            root)
                STATE_ROOT_NAMES[${#STATE_ROOT_NAMES[@]}]="$a"
                STATE_ROOT_PRESENT[${#STATE_ROOT_PRESENT[@]}]="$b"
                STATE_ROOT_COUNTS[${#STATE_ROOT_COUNTS[@]}]="$c"
                ;;
        esac
    done < "$file"

}

env_backup_state_root_count() {

    local want="$1"
    local i=0
    local n=0

    n=${#STATE_ROOT_NAMES[@]}

    while [ "$i" -lt "$n" ]; do
        if [ "${STATE_ROOT_NAMES[$i]}" = "$want" ]; then
            printf '%s\n' "${STATE_ROOT_COUNTS[$i]}"
            return 0
        fi
        i=$((i + 1))
    done

    printf '%s\n' "0"
    return 1

}

env_backup_write_state() {

    local snapshot="$1"
    local hash="$2"
    local created="$3"
    local total="$4"
    local partial="$5"
    local stats="$6"
    local tmp=""
    local name=""
    local present=""
    local count=""

    tmp="$ENV_BACKUP_DIR/state.tmp.$$"

    {
        printf '%s\n' "version 1"
        printf 'snapshot %s\n' "$snapshot"
        printf 'hash %s\n' "$hash"
        printf 'created %s\n' "$created"
        printf 'files %s\n' "$total"
        printf 'partial %s\n' "$partial"

        while IFS="$(printf '\t')" read -r name present count; do
            [ -n "$name" ] || continue
            printf 'root %s %s %s\n' "$name" "$present" "$count"
        done < "$stats"
    } > "$tmp"

    command mv -f -- "$tmp" "$ENV_BACKUP_DIR/state"
    command chmod 600 "$ENV_BACKUP_DIR/state" 2> /dev/null || true

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

env_backup_need_age() {

    command -v age > /dev/null 2>&1 || env_backup_die "age is not installed (brew install age)"
    command -v age-keygen > /dev/null 2>&1 || env_backup_die "age-keygen is not installed (brew install age)"

}

env_backup_user_name() {

    if [ -n "${USER:-}" ]; then
        printf '%s\n' "$USER"
        return 0
    fi

    id -un

}

env_backup_recipient_file() {

    printf '%s\n' "$ENV_BACKUP_CONFIG_DIR/recipient"

}

env_backup_read_recipient() {

    local file=""
    local line=""

    file=$(env_backup_recipient_file)

    [ -f "$file" ] || return 1

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ""|\#*)
                continue
                ;;
            age1*)
                printf '%s\n' "$line"
                return 0
                ;;
        esac
    done < "$file"

    return 1

}

env_backup_write_recipient() {

    local recipient="$1"
    local file=""

    env_backup_ensure_config_dir
    file=$(env_backup_recipient_file)

    printf '%s\n' "$recipient" > "$file"
    command chmod 644 "$file"

}

env_backup_repo_root() {

    local dir=""

    if [ -z "${ENV_BACKUP_BIN_DIR:-}" ]; then
        return 1
    fi

    dir=$(cd "$ENV_BACKUP_BIN_DIR/.." && pwd)

    if command -v git > /dev/null 2>&1 && git -C "$dir" rev-parse --show-toplevel > /dev/null 2>&1; then
        git -C "$dir" rev-parse --show-toplevel
        return 0
    fi

    printf '%s\n' "$dir"

}

env_backup_realpath() {

    local path="$1"
    local parent=""
    local base=""

    if [ -d "$path" ]; then
        (cd "$path" && pwd -P)
        return 0
    fi

    parent=$(env_backup_dirname "$path")
    base=$(env_backup_basename "$path")

    if [ -d "$parent" ]; then
        printf '%s/%s\n' "$(cd "$parent" && pwd -P)" "$base"
        return 0
    fi

    printf '%s\n' "$path"

}

env_backup_path_is_under() {

    local child="$1"
    local parent="$2"
    local child_real=""
    local parent_real=""

    [ -n "$parent" ] || return 1

    child_real=$(env_backup_realpath "$child")

    if [ -d "$parent" ]; then
        parent_real=$(env_backup_realpath "$parent")
    else
        parent_real="$parent"
    fi

    case "$child_real" in
        "$parent_real"|"$parent_real"/*)
            return 0
            ;;
    esac

    case "$child" in
        "$parent"|"$parent"/*)
            return 0
            ;;
    esac

    return 1

}

env_backup_assert_key_not_in_unsafe_place() {

    local path="$1"
    local repo=""
    local drive_root=""

    [ -n "$path" ] || env_backup_die "missing identity path"

    if env_backup_path_is_under "$path" "$ENV_BACKUP_DIR"; then
        env_backup_die "refusing to put the age identity in the backup folder"
    fi

    drive_root="$HOME/Library/CloudStorage"

    if [ -d "$drive_root" ] && env_backup_path_is_under "$path" "$drive_root"; then
        env_backup_die "refusing to put the age identity in CloudStorage"
    fi

    repo=$(env_backup_repo_root || true)

    if [ -n "$repo" ] && env_backup_path_is_under "$path" "$repo"; then
        env_backup_die "refusing to put the age identity in the dotfiles repo"
    fi

}

env_backup_secret_from_text() {

    local line=""
    local found=""

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            AGE-SECRET-KEY-1*)
                found="$line"
                ;;
        esac
    done

    [ -n "$found" ] || return 1

    printf '%s\n' "$found"

}

env_backup_public_from_secret() {

    local secret="$1"
    local work=""
    local recipient=""

    work=$(env_backup_mktmp)
    printf '%s\n' "$secret" > "$work/identity"
    command chmod 600 "$work/identity"
    recipient=$(age-keygen -y "$work/identity") || return 1
    command rm -f -- "$work/identity"
    printf '%s\n' "$recipient"

}

env_backup_wipe_file() {

    local file="$1"

    [ -f "$file" ] || return 0

    # Best effort. The file lives only in a 0700 temp dir.
    dd if=/dev/zero of="$file" bs=512 count=1 > /dev/null 2>&1 || true
    command rm -f -- "$file"

}

env_backup_roundtrip_check() {

    local secret="$1"
    local recipient="$2"
    local work=""
    local derived=""

    work=$(env_backup_mktmp)
    printf '%s\n' "$secret" > "$work/identity"
    command chmod 600 "$work/identity"

    derived=$(age-keygen -y "$work/identity") || env_backup_die "could not derive the public recipient"
    [ "$derived" = "$recipient" ] || env_backup_die "public recipient does not match the identity"

    printf '%s\n' "env-backup-setup-check" | age -r "$recipient" -o "$work/check.age" || env_backup_die "could not encrypt a setup check"
    age -d -i "$work/identity" -o "$work/check.txt" "$work/check.age" || env_backup_die "could not decrypt the setup check"
    [ "$(cat "$work/check.txt")" = "env-backup-setup-check" ] || env_backup_die "setup check did not round-trip"

    env_backup_wipe_file "$work/identity"

}

env_backup_keychain_available() {

    [ "$(uname)" = "Darwin" ] || return 1
    command -v security > /dev/null 2>&1 || return 1
    return 0

}

env_backup_keychain_exists() {

    local user=""

    user=$(env_backup_user_name)
    security find-generic-password \
        -a "$user" \
        -s "$ENV_BACKUP_KEYCHAIN_SERVICE" \
        > /dev/null 2>&1

}

env_backup_keychain_store() {

    local secret="$1"
    local user=""

    user=$(env_backup_user_name)

    # `security -w` has to see the secret on argv. This is the brief
    # window that cannot be avoided with the `security` CLI. The key
    # is not written into the repo or into Drive.
    set +x
    security add-generic-password \
        -U \
        -a "$user" \
        -s "$ENV_BACKUP_KEYCHAIN_SERVICE" \
        -l "env-backup age identity" \
        -j "age identity for env-backup. The public recipient is in ~/.config/env-backup/recipient." \
        -T /usr/bin/security \
        -w "$secret"

}

env_backup_keychain_read() {

    local user=""
    local secret=""

    user=$(env_backup_user_name)
    set +x
    secret=$(security find-generic-password -a "$user" -s "$ENV_BACKUP_KEYCHAIN_SERVICE" -w) || return 1
    secret=${secret%$'\r'}

    case "$secret" in
        AGE-SECRET-KEY-1*)
            printf '%s\n' "$secret"
            ;;
        *)
            printf '%s\n' "$secret" | env_backup_secret_from_text
            ;;
    esac

}

env_backup_load_secret() {

    local secret=""

    if [ -n "${ENV_BACKUP_IDENTITY_FILE:-}" ]; then
        env_backup_assert_key_not_in_unsafe_place "$ENV_BACKUP_IDENTITY_FILE"
        [ -f "$ENV_BACKUP_IDENTITY_FILE" ] || env_backup_die "identity file does not exist"
        secret=$(env_backup_secret_from_text < "$ENV_BACKUP_IDENTITY_FILE") || env_backup_die "identity file has no AGE-SECRET-KEY line"
        printf '%s\n' "$secret"
        return 0
    fi

    if env_backup_keychain_available; then
        env_backup_keychain_read
        return $?
    fi

    env_backup_die "no age identity available. Run env-backup setup, or import a saved key."

}

env_backup_materialize_identity() {

    local dest="$1"
    local secret=""

    secret=$(env_backup_load_secret) || return 1
    printf '%s\n' "$secret" > "$dest"
    command chmod 600 "$dest"

}

env_backup_print_identity_block() {

    local secret="$1"
    local recipient="$2"

    printf '\n%s\n' "Save this identity in your password manager."
    printf '%s\n' "Do not store it in this git repo or in Google Drive."
    printf '%s\n' "It is the only way to decrypt backups if the Mac keychain is lost."
    printf '\n%s\n' "----- BEGIN AGE IDENTITY -----"
    printf '%s\n' "# public key: $recipient"
    printf '%s\n' "$secret"
    printf '%s\n\n' "----- END AGE IDENTITY -----"

}

env_backup_store_secret() {

    local secret="$1"
    local parent=""

    if [ "${ENV_BACKUP_ALLOW_IDENTITY_FILE:-}" = "1" ]; then
        [ -n "${ENV_BACKUP_IDENTITY_FILE:-}" ] || env_backup_die "ENV_BACKUP_IDENTITY_FILE is required in identity-file mode"
        env_backup_assert_key_not_in_unsafe_place "$ENV_BACKUP_IDENTITY_FILE"
        parent=$(env_backup_dirname "$ENV_BACKUP_IDENTITY_FILE")
        command mkdir -p -- "$parent"
        printf '%s\n' "$secret" > "$ENV_BACKUP_IDENTITY_FILE"
        command chmod 600 "$ENV_BACKUP_IDENTITY_FILE"
        return 0
    fi

    env_backup_keychain_available || env_backup_die "setup stores the identity in the macOS login keychain. This machine has no \`security\` command."

    if ! env_backup_keychain_store "$secret"; then
        printf '%s\n' "could not store the identity in the login keychain" >&2
        return 1
    fi

    local readback=""
    readback=$(env_backup_keychain_read) || {
        printf '%s\n' "could not read the identity back from the keychain" >&2
        return 1
    }
    if [ "$readback" != "$secret" ]; then
        printf '%s\n' "keychain read-back did not match the new identity" >&2
        return 1
    fi

}

env_backup_confirm_rotate() {

    local answer=""

    if [ "${ENV_BACKUP_ASSUME_YES:-}" = "1" ]; then
        return 0
    fi

    if [ ! -t 0 ]; then
        env_backup_die "refusing to rotate a key without a terminal. Set ENV_BACKUP_ASSUME_YES=1 to override."
    fi

    printf '%s\n' "This replaces the keychain identity. Older backups will not open with the new key unless you still have the previous one." >&2
    printf '%s' "Type rotate to continue: " >&2
    IFS= read -r answer
    [ "$answer" = "rotate" ] || env_backup_die "aborted"

}

env_backup_identity_already_present() {

    if [ "${ENV_BACKUP_ALLOW_IDENTITY_FILE:-}" = "1" ]; then
        [ -n "${ENV_BACKUP_IDENTITY_FILE:-}" ] && [ -f "$ENV_BACKUP_IDENTITY_FILE" ]
        return $?
    fi

    if env_backup_keychain_available; then
        env_backup_keychain_exists
        return $?
    fi

    return 1

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

env_backup_list_snapshot_files() {

    local dir="$ENV_BACKUP_DIR"
    local file=""
    local base=""

    [ -d "$dir" ] || return 0

    for file in "$dir"/dotenv-*.age; do
        [ -f "$file" ] || continue
        base=$(env_backup_basename "$file")
        env_backup_valid_snapshot_name "$base" || continue
        printf '%s\n' "$file"
    done | LC_ALL=C sort -r

}

env_backup_newest_snapshot() {

    local file=""

    file=$(env_backup_list_snapshot_files)
    [ -n "$file" ] || return 0
    printf '%s\n' "${file%%$'\n'*}"

}

env_backup_resolve_snapshot() {

    local name="${1:-}"
    local path=""

    if [ -z "$name" ] || [ "$name" = "--latest" ]; then
        path=$(env_backup_newest_snapshot || true)
        [ -n "$path" ] || env_backup_die "no snapshots in $ENV_BACKUP_DIR"
        printf '%s\n' "$path"
        return 0
    fi

    if [ -f "$name" ]; then
        printf '%s\n' "$name"
        return 0
    fi

    if [ -f "$ENV_BACKUP_DIR/$name" ]; then
        printf '%s\n' "$ENV_BACKUP_DIR/$name"
        return 0
    fi

    env_backup_die "snapshot not found: $name"

}

env_backup_plan_retention() (

    # stdin: snapshot basenames
    # stdout: basenames to keep
    local keep_recent="$1"
    local keep_daily="$2"
    local keep_monthly="$3"
    local sorted=""
    local name=""
    local day=""
    local month=""
    local recent_kept=0
    local daily_kept=0
    local monthly_kept=0
    local seen_days=$'\n'
    local seen_months=$'\n'
    local keep_this=1

    if [ "$keep_recent" -lt 1 ]; then
        keep_recent=1
    fi

    sorted=$(LC_ALL=C sort -r)

    [ -n "$sorted" ] || return 0

    set -f
    IFS=$'\n'

    for name in $sorted; do
        [ -n "$name" ] || continue
        env_backup_valid_snapshot_name "$name" || continue

        day=$(env_backup_snapshot_stamp "$name")
        day=${day%%T*}
        month=${day:0:6}
        keep_this=1

        if [ "$recent_kept" -lt "$keep_recent" ]; then
            keep_this=0
            recent_kept=$((recent_kept + 1))
        fi

        case "$seen_days" in
            *$'\n'"$day"$'\n'*)
                ;;
            *)
                if [ "$daily_kept" -lt "$keep_daily" ]; then
                    keep_this=0
                    daily_kept=$((daily_kept + 1))
                fi
                seen_days="${seen_days}${day}"$'\n'
                ;;
        esac

        case "$seen_months" in
            *$'\n'"$month"$'\n'*)
                ;;
            *)
                if [ "$monthly_kept" -lt "$keep_monthly" ]; then
                    keep_this=0
                    monthly_kept=$((monthly_kept + 1))
                fi
                seen_months="${seen_months}${month}"$'\n'
                ;;
        esac

        if [ "$keep_this" -eq 0 ]; then
            printf '%s\n' "$name"
        fi
    done

)

env_backup_keep_has() {

    local haystack="$1"
    local needle="$2"
    local line=""

    while IFS= read -r line; do
        [ "$line" = "$needle" ] && return 0
    done << EOF
$haystack
EOF

    return 1

}

env_backup_clean_partials() {

    local file=""

    [ -d "$ENV_BACKUP_DIR" ] || return 0

    for file in "$ENV_BACKUP_DIR"/dotenv-*.age.partial; do
        [ -f "$file" ] || continue
        command rm -f -- "$file"
    done

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

env_backup_root_index_count() {

    printf '%s\n' "${#ROOT_NAMES[@]}"

}

env_backup_scan_all() {

    local list="$1"
    local stats="$2"
    local allow_partial="$3"
    local i=0
    local n=0
    local name=""
    local path=""
    local before=0
    local after=0
    local count=0
    local previous=0
    local blocked=0

    : > "$list"
    : > "$stats"

    n=$(env_backup_root_index_count)

    while [ "$i" -lt "$n" ]; do
        name=${ROOT_NAMES[$i]}
        path=${ROOT_PATHS[$i]}

        if [ ! -d "$path" ]; then
            previous=$(env_backup_state_root_count "$name" || true)
            env_backup_log "root $name is not available ($path)"

            if [ "${previous:-0}" -gt 0 ] && [ "$allow_partial" -ne 1 ]; then
                blocked=1
            fi

            # Keep the last seen count so a missing disk still counts as
            # "this root has files we must not drop".
            printf '%s\t0\t%s\n' "$name" "${previous:-0}" >> "$stats"
            i=$((i + 1))
            continue
        fi

        before=$(env_backup_line_count "$list")
        env_backup_scan_root "$name" "$path" "$list"
        after=$(env_backup_line_count "$list")
        count=$((after - before))
        env_backup_log "root $name ($path): $count secret file(s)"
        printf '%s\t1\t%s\n' "$name" "$count" >> "$stats"
        i=$((i + 1))
    done

    if [ "$blocked" -eq 1 ]; then
        return 2
    fi

    return 0

}

env_backup_copy_payload() {

    local list="$1"
    local stage="$2"
    local namespace=""
    local rel=""
    local path=""
    local dest=""

    command mkdir -p -- "$stage/payload"

    while IFS="$(printf '\t')" read -r namespace rel path; do
        [ -n "$namespace" ] || continue
        dest="$stage/payload/$namespace/$rel"
        command mkdir -p -- "$(env_backup_dirname "$dest")"
        command cp -- "$path" "$dest"
        command chmod 600 "$dest"
    done < "$list"

}

env_backup_pack_stage() {

    local stage="$1"

    (
        cd "$stage" || exit 1
        COPYFILE_DISABLE=1 tar -cf "$stage/archive.tar" manifest.tsv payload
    )

}

env_backup_encrypt_archive() {

    local archive="$1"
    local destination="$2"
    local recipient=""

    recipient=$(env_backup_read_recipient) || env_backup_die "no public recipient. Run env-backup setup first."

    case "$recipient" in
        age1*)
            ;;
        *)
            env_backup_die "recipient does not look like an age public key"
            ;;
    esac

    ENV_BACKUP_PARTIAL="$destination"
    age -r "$recipient" -o "$destination" "$archive"

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

env_backup_cmd_help() {

    cat << 'EOF'
env-backup — encrypted backups of secret env files

Usage:
  env-backup setup [--force]
  env-backup import-identity [--force]
  env-backup export-identity
  env-backup backup [--dry-run] [--unattended] [--allow-partial]
  env-backup status
  env-backup list
  env-backup show [SNAPSHOT]
  env-backup diff [SNAPSHOT]
  env-backup restore [SNAPSHOT] [--path PREFIX] [--dry-run] [--force]
  env-backup prune [--dry-run]
  env-backup migrate [--apply] [--force] [--root NAME] [--path PREFIX]
  env-backup install-agent [--print]
  env-backup uninstall-agent

Both project roots are scanned together:
  home   ~/projects
  adata  /Volumes/ADATA-GFELIZOLA/projects   (skipped when the disk is absent)

Snapshots are encrypted to the age recipient only, so the daily job does
not need the private key. The private key stays in the macOS login
keychain. Put an offline copy in a password manager; do not put it in
git or in Google Drive.

Matching is a broad .env* (and .dev.vars) include list. Templates
(*.example, *.sample, *.template, *.dist) are excluded. node_modules,
.git, and build outputs are not walked. Tracked .env files are included.

Environment:
  ENV_BACKUP_DIR            destination directory
  ENV_BACKUP_ROOTS          newline-separated name|/path overrides
  ENV_BACKUP_KEEP_RECENT    newest snapshots always kept (default 3)
  ENV_BACKUP_KEEP_DAILY     distinct days to keep (default 14)
  ENV_BACKUP_KEEP_MONTHLY   distinct months to keep (default 12)
  ENV_BACKUP_VAULT          old Cryptomator mount (default /Volumes/DotEnvs)

Exit status:
  0  success, nothing to do, or a missing Drive/disk in --unattended mode
  1  error
  2  usage error
EOF

}

env_backup_cmd_setup() {

    local force=0
    local work=""
    local identity=""
    local secret=""
    local recipient=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --force)
                force=1
                ;;
            *)
                env_backup_die "unknown argument: $1"
                ;;
        esac
        shift
    done

    env_backup_need_age
    env_backup_ensure_config_dir

    if env_backup_identity_already_present; then
        if [ "$force" -ne 1 ]; then
            env_backup_die "an identity already exists. Run env-backup setup --force to rotate it."
        fi
        env_backup_confirm_rotate
    fi

    work=$(env_backup_mktmp)
    identity=$(age-keygen 2> "$work/age-keygen.err") || env_backup_die "age-keygen failed"
    secret=$(printf '%s\n' "$identity" | env_backup_secret_from_text) || env_backup_die "age-keygen did not return a secret key"
    recipient=$(env_backup_public_from_secret "$secret") || env_backup_die "could not derive the public recipient"

    env_backup_roundtrip_check "$secret" "$recipient"

    if ! env_backup_store_secret "$secret"; then
        if [ "${ENV_BACKUP_SETUP_QUIET:-}" != "1" ]; then
            env_backup_print_identity_block "$secret" "$recipient"
        fi
        env_backup_die "the identity was not stored"
    fi

    env_backup_write_recipient "$recipient"
    env_backup_wipe_file "$work/identity" 2> /dev/null || true

    if [ "${ENV_BACKUP_SETUP_QUIET:-}" = "1" ]; then
        printf '%s\n' "recipient $recipient"
        return 0
    fi

    env_backup_print_identity_block "$secret" "$recipient"
    printf '%s\n' "Public recipient (not secret): $recipient"
    printf '%s\n' "Recipient file: $(env_backup_recipient_file)"

    if [ "${ENV_BACKUP_ALLOW_IDENTITY_FILE:-}" = "1" ]; then
        printf '%s\n' "Identity file mode is on. The key is in $ENV_BACKUP_IDENTITY_FILE"
    else
        printf '%s\n' "Private key: login keychain item $ENV_BACKUP_KEYCHAIN_SERVICE"
    fi

    printf '%s\n' "Next: env-backup backup --dry-run"
    printf '%s\n' "Then: env-backup backup"
    printf '%s\n' "Daily job: env-backup install-agent"

}

env_backup_cmd_import_identity() {

    local force=0
    local text=""
    local secret=""
    local recipient=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --force)
                force=1
                ;;
            *)
                env_backup_die "unknown argument: $1"
                ;;
        esac
        shift
    done

    env_backup_need_age
    env_backup_ensure_config_dir

    if [ -t 0 ]; then
        printf '%s\n' "Paste the age identity, then press Ctrl-D." >&2
    fi

    text=$(cat) || env_backup_die "could not read the identity"
    secret=$(printf '%s\n' "$text" | env_backup_secret_from_text) || env_backup_die "no AGE-SECRET-KEY line in the pasted identity"
    recipient=$(env_backup_public_from_secret "$secret") || env_backup_die "could not derive the public recipient"
    env_backup_roundtrip_check "$secret" "$recipient"

    if env_backup_identity_already_present; then
        if [ "$force" -ne 1 ]; then
            env_backup_die "an identity already exists. Re-run with --force to replace it."
        fi
        env_backup_confirm_rotate
    fi

    env_backup_store_secret "$secret"
    env_backup_write_recipient "$recipient"

    printf '%s\n' "Imported age identity."
    printf '%s\n' "Public recipient: $recipient"

}

env_backup_stdout_file() {

    # fd 3 must already be a duplicate of the original stdout. Calling this
    # inside a command substitution would make fd 1 a pipe.
    local work=""
    local line=""
    local path=""

    work=$(env_backup_mktmp)

    if [ -e /dev/fd/3 ]; then
        readlink /dev/fd/3 > "$work/link" 2> /dev/null || true
        path=$(cat "$work/link" 2> /dev/null || true)
    fi

    case "$path" in
        /*)
            printf '%s\n' "$path"
            return 0
            ;;
    esac

    if command -v lsof > /dev/null 2>&1; then
        # $$ stays the shell pid inside this function. -d 3 is the
        # duplicated stdout, which is what macOS needs: /dev/fd is not
        # a regular file there, so readlink does not see the target.
        lsof -a -p "$$" -d 3 -F n > "$work/lsof" 2> /dev/null || true
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                n/*)
                    path=${line#n}
                    path=${path%$'\r'}
                    ;;
            esac
        done < "$work/lsof"
    fi

    case "$path" in
        /*)
            printf '%s\n' "$path"
            ;;
    esac

}

env_backup_cmd_export_identity() {

    local secret=""
    local recipient=""
    local stdout_path=""

    env_backup_need_age

    exec 3>&1
    stdout_path=$(env_backup_stdout_file || true)
    exec 3>&-

    case "$stdout_path" in
        ""|/dev/*|pipe:*|socket:*)
            ;;
        *)
            env_backup_assert_key_not_in_unsafe_place "$stdout_path"
            ;;
    esac

    secret=$(env_backup_load_secret) || env_backup_die "could not load the identity"
    recipient=$(env_backup_public_from_secret "$secret") || env_backup_die "could not derive the public recipient"

    printf '%s\n' "# public key: $recipient"
    printf '%s\n' "$secret"

}

env_backup_cmd_backup() {

    local dry=0
    local unattended=0
    local allow_partial=0
    local work=""
    local list=""
    local stats=""
    local manifest=""
    local hash=""
    local previous=""
    local scan_status=0
    local total=0
    local partial=0
    local stamp=""
    local name=""
    local final=""
    local partial_file=""
    local recipient=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                dry=1
                ;;
            --unattended)
                unattended=1
                ;;
            --allow-partial)
                allow_partial=1
                ;;
            *)
                env_backup_die "unknown argument: $1"
                ;;
        esac
        shift
    done

    if [ "$dry" -eq 0 ]; then
        env_backup_lock
    fi

    if [ "$dry" -eq 0 ]; then
        if ! env_backup_destination_ready 1; then
            env_backup_log "backup folder is not available ($ENV_BACKUP_DIR). Google Drive is probably not mounted."
            if [ "$unattended" -eq 1 ]; then
                exit 0
            fi
            env_backup_die "backup folder is not available: $ENV_BACKUP_DIR"
        fi
    fi

    env_backup_load_state || true

    work=$(env_backup_mktmp)
    list="$work/files.tsv"
    stats="$work/stats.tsv"
    manifest="$work/manifest.tsv"

    set +e
    env_backup_scan_all "$list" "$stats" "$allow_partial"
    scan_status=$?
    set -e

    if [ "$scan_status" -eq 2 ]; then
        env_backup_log "not writing a snapshot. A root that already has backed-up files is unavailable."
        env_backup_log "Plug that disk back in. Pass --allow-partial only if those files are gone for good."
        exit 0
    fi

    if [ "$scan_status" -ne 0 ]; then
        env_backup_die "scan failed"
    fi

    # A snapshot is partial when any configured root directory is missing.
    if grep -q "$(printf '\t')0$(printf '\t')" "$stats"; then
        partial=1
    fi

    env_backup_build_manifest "$list" "$manifest"
    hash=$(env_backup_manifest_hash "$manifest")
    total=$(awk -F '\t' '/^#/ { next } NF >= 3 { n++ } END { print n + 0 }' "$manifest")

    if [ "$dry" -eq 1 ]; then
        printf '%s\n' "dry-run: destination $ENV_BACKUP_DIR"
        printf '%s\n' "dry-run: files $total"
        printf '%s\n' "dry-run: manifest $hash"
        if [ "$partial" -eq 1 ]; then
            printf '%s\n' "dry-run: partial (a configured root is missing)"
        fi
        awk -F '\t' 'NF >= 2 { printf "include\t%s\t%s\n", $1, $2 }' "$list" | LC_ALL=C sort
        previous=""
        if [ -d "$ENV_BACKUP_DIR" ]; then
            env_backup_load_state || true
            previous="${STATE_HASH:-}"
        fi
        if [ -n "$previous" ] && [ "$previous" = "$hash" ] && [ "$partial" -eq 0 ]; then
            printf '%s\n' "dry-run: unchanged; would not write a snapshot"
        else
            printf '%s\n' "dry-run: would write a snapshot"
        fi
        if ! env_backup_read_recipient > /dev/null 2>&1; then
            printf '%s\n' "dry-run: no recipient yet. Run env-backup setup before a real backup."
        fi
        return 0
    fi

    env_backup_clean_partials

    if [ "$partial" -eq 0 ] && [ -n "${STATE_HASH:-}" ] && [ "$STATE_HASH" = "$hash" ]; then
        if [ -n "${STATE_SNAPSHOT:-}" ] && [ -f "$ENV_BACKUP_DIR/$STATE_SNAPSHOT" ]; then
            env_backup_log "unchanged since ${STATE_SNAPSHOT}; not writing a new snapshot"
            env_backup_cmd_prune
            return 0
        fi
    fi

    if ! recipient=$(env_backup_read_recipient); then
        env_backup_log "no public recipient yet. Run env-backup setup."
        if [ "$unattended" -eq 1 ]; then
            exit 0
        fi
        env_backup_die "no public recipient. Run env-backup setup first."
    fi

    env_backup_copy_payload "$list" "$work"
    env_backup_pack_stage "$work"

    stamp=$(env_backup_now_stamp)
    name="dotenv-${stamp}.age"
    final="$ENV_BACKUP_DIR/$name"
    partial_file="$ENV_BACKUP_DIR/$name.partial"

    if [ -e "$final" ]; then
        env_backup_die "snapshot already exists: $name"
    fi

    env_backup_encrypt_archive "$work/archive.tar" "$partial_file"
    command mv -f -- "$partial_file" "$final"
    ENV_BACKUP_PARTIAL=""
    command chmod 600 "$final" 2> /dev/null || true

    env_backup_write_state "$name" "$hash" "$stamp" "$total" "$partial" "$stats"
    env_backup_log "wrote $name ($total file(s), partial=$partial)"

    if [ "$partial" -eq 1 ]; then
        env_backup_log "skipping retention prune because this snapshot did not see every root"
    else
        env_backup_cmd_prune
    fi

}

env_backup_decrypt_snapshot() {

    local snapshot="$1"
    local stage="$2"
    local identity="$stage/identity"

    env_backup_need_age
    env_backup_materialize_identity "$identity" || return 1

    if ! age -d -i "$identity" -o "$stage/archive.tar" "$snapshot"; then
        env_backup_wipe_file "$identity"
        printf 'env-backup: could not decrypt %s\n' "$snapshot" >&2
        return 1
    fi

    env_backup_wipe_file "$identity"
    command mkdir -p -- "$stage/out"

    if ! tar -xf "$stage/archive.tar" -C "$stage/out"; then
        printf 'env-backup: could not unpack %s\n' "$snapshot" >&2
        return 1
    fi

    if [ ! -f "$stage/out/manifest.tsv" ]; then
        printf 'env-backup: snapshot has no manifest\n' >&2
        return 1
    fi
}

env_backup_manifest_rows() {

    awk -F '\t' '
        /^#/ { next }
        NF >= 4 { print $1 "\t" $2 "\t" $3 "\t" $4 }
    ' "$1"

}

env_backup_diff_files() {

    local old="$1"
    local new="$2"
    local absent="$3"

    awk -F '\t' -v absent=",$absent," '
        /^#/ { next }
        NF < 3 { next }
        NR == FNR {
            key = $1 "\t" $2
            old[key] = $3
            next
        }
        {
            key = $1 "\t" $2
            new[key] = $3
        }
        END {
            for (k in old) {
                split(k, p, "\t")
                ns = p[1]
                rel = p[2]
                if (index(absent, "," ns ",") > 0) {
                    printf "?	%s	%s	unavailable\n", ns, rel
                    continue
                }
                if (!(k in new)) {
                    printf "-	%s	%s	removed\n", ns, rel
                } else if (old[k] != new[k]) {
                    printf "~	%s	%s	changed\n", ns, rel
                }
            }
            for (k in new) {
                if (!(k in old)) {
                    split(k, p, "\t")
                    printf "+	%s	%s	added\n", p[1], p[2]
                }
            }
        }
    ' "$old" "$new" | LC_ALL=C sort

}

env_backup_absent_roots_csv() {

    local i=0
    local n=0
    local csv=""

    n=$(env_backup_root_index_count)

    while [ "$i" -lt "$n" ]; do
        if [ ! -d "${ROOT_PATHS[$i]}" ]; then
            csv="${csv}${ROOT_NAMES[$i]},"
        fi
        i=$((i + 1))
    done

    printf '%s\n' "$csv"

}

env_backup_cmd_status() {

    local work=""
    local list=""
    local manifest=""
    local hash=""
    local total=0
    local i=0
    local n=0
    local name=""
    local path=""
    local count=0
    local present="missing"
    local newest=""
    local diff=""
    local stage=""

    printf '%s\n' "destination: $ENV_BACKUP_DIR"

    if env_backup_destination_ready 0 && [ -d "$ENV_BACKUP_DIR" ]; then
        env_backup_load_state || true
        if [ -n "${STATE_SNAPSHOT:-}" ]; then
            printf 'last backup: %s (%s)\n' "$(env_backup_format_stamp "$STATE_CREATED")" "$STATE_SNAPSHOT"
            printf 'last file count: %s\n' "${STATE_FILES:-0}"
            if [ "${STATE_PARTIAL:-0}" = "1" ]; then
                printf '%s\n' "last snapshot was partial (a root was missing)"
            fi
        else
            newest=$(env_backup_newest_snapshot || true)
            if [ -n "$newest" ]; then
                printf 'last backup: %s\n' "$(env_backup_format_stamp "$(env_backup_snapshot_stamp "$newest")")"
            else
                printf '%s\n' "last backup: none"
            fi
        fi
    else
        printf '%s\n' "last backup: destination unavailable"
    fi

    if env_backup_read_recipient > /dev/null 2>&1; then
        printf 'recipient: %s\n' "$(env_backup_read_recipient)"
    else
        printf '%s\n' "recipient: not set (run env-backup setup)"
    fi

    work=$(env_backup_mktmp)
    list="$work/files.tsv"
    manifest="$work/manifest.tsv"
    : > "$list"

    printf '%s\n' "roots:"
    n=$(env_backup_root_index_count)
    i=0

    while [ "$i" -lt "$n" ]; do
        name=${ROOT_NAMES[$i]}
        path=${ROOT_PATHS[$i]}

        if [ -d "$path" ]; then
            present="present"
            env_backup_scan_root "$name" "$path" "$list"
        else
            present="missing"
        fi

        count=$(awk -F '\t' -v ns="$name" '$1 == ns { n++ } END { print n + 0 }' "$list")
        printf '  %s  %s  %s file(s)  %s\n' "$name" "$path" "$count" "$present"
        i=$((i + 1))
    done

    env_backup_build_manifest "$list" "$manifest"
    hash=$(env_backup_manifest_hash "$manifest")
    total=$(awk -F '\t' '/^#/ { next } NF >= 3 { n++ } END { print n + 0 }' "$manifest")
    printf 'visible now: %s file(s)\n' "$total"

    if [ -z "${STATE_HASH:-}" ]; then
        printf '%s\n' "changes: no previous snapshot to compare"
        return 0
    fi

    if [ "$STATE_HASH" = "$hash" ]; then
        printf '%s\n' "changes: nothing new or changed since the last backup"
        return 0
    fi

    if [ ! -d "$ENV_BACKUP_DIR" ] || [ -z "${STATE_SNAPSHOT:-}" ] || [ ! -f "$ENV_BACKUP_DIR/$STATE_SNAPSHOT" ]; then
        printf '%s\n' "changes: manifest differs, but the last snapshot file is missing"
        return 0
    fi

    stage=$(env_backup_mktmp)

    if ! env_backup_decrypt_snapshot "$ENV_BACKUP_DIR/$STATE_SNAPSHOT" "$stage"; then
        printf '%s\n' "changes: manifest differs. Unlock the keychain to see which files."
        return 0
    fi

    diff=$(env_backup_diff_files "$stage/out/manifest.tsv" "$manifest" "$(env_backup_absent_roots_csv)")

    if [ -z "$diff" ]; then
        printf '%s\n' "changes: nothing new or changed since the last backup"
        return 0
    fi

    printf '%s\n' "changes:"
    printf '%s\n' "$diff"

}

env_backup_cmd_list() {

    local file=""
    local base=""
    local bytes=0
    local found=0

    if [ ! -d "$ENV_BACKUP_DIR" ]; then
        env_backup_die "backup folder is not available: $ENV_BACKUP_DIR"
    fi

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        found=1
        base=$(env_backup_basename "$file")
        bytes=$(wc -c < "$file" | tr -d ' ')
        printf '%s  %s bytes  %s\n' "$(env_backup_format_stamp "$(env_backup_snapshot_stamp "$base")")" "$bytes" "$base"
    done << EOF
$(env_backup_list_snapshot_files)
EOF

    if [ "$found" -eq 0 ]; then
        printf '%s\n' "no snapshots in $ENV_BACKUP_DIR"
    fi

}

env_backup_cmd_show() {

    local snapshot=""
    local stage=""

    snapshot=$(env_backup_resolve_snapshot "${1:-}")
    stage=$(env_backup_mktmp)
    env_backup_decrypt_snapshot "$snapshot" "$stage" || env_backup_die "could not read snapshot"
    printf 'snapshot: %s\n' "$(env_backup_basename "$snapshot")"
    env_backup_manifest_rows "$stage/out/manifest.tsv"

}

env_backup_cmd_diff() {

    local snapshot=""
    local stage=""
    local work=""
    local list=""
    local manifest=""
    local diff=""
    local arg=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --)
                shift
                break
                ;;
            -*)
                env_backup_die "unknown argument: $1"
                ;;
            *)
                arg="$1"
                ;;
        esac
        shift
    done

    snapshot=$(env_backup_resolve_snapshot "$arg")
    stage=$(env_backup_mktmp)
    env_backup_decrypt_snapshot "$snapshot" "$stage" || env_backup_die "could not read snapshot"

    work=$(env_backup_mktmp)
    list="$work/files.tsv"
    manifest="$work/manifest.tsv"
    : > "$list"

    local i=0
    local n=0

    n=$(env_backup_root_index_count)

    while [ "$i" -lt "$n" ]; do
        if [ -d "${ROOT_PATHS[$i]}" ]; then
            env_backup_scan_root "${ROOT_NAMES[$i]}" "${ROOT_PATHS[$i]}" "$list"
        fi
        i=$((i + 1))
    done

    env_backup_build_manifest "$list" "$manifest"
    diff=$(env_backup_diff_files "$stage/out/manifest.tsv" "$manifest" "$(env_backup_absent_roots_csv)")

    printf 'snapshot: %s\n' "$(env_backup_basename "$snapshot")"

    if [ -z "$diff" ]; then
        printf '%s\n' "no differences"
        return 0
    fi

    printf '%s\n' "$diff"

}

env_backup_path_selected() {

    local namespace="$1"
    local rel="$2"
    local filter="$3"

    [ -n "$filter" ] || return 0

    case "$namespace/$rel" in
        "$filter"|"$filter"/*)
            return 0
            ;;
    esac

    case "$rel" in
        "$filter"|"$filter"/*)
            return 0
            ;;
    esac

    return 1

}

env_backup_root_path_by_name() {

    local want="$1"
    local i=0
    local n=0

    n=$(env_backup_root_index_count)

    while [ "$i" -lt "$n" ]; do
        if [ "${ROOT_NAMES[$i]}" = "$want" ]; then
            printf '%s\n' "${ROOT_PATHS[$i]}"
            return 0
        fi
        i=$((i + 1))
    done

    return 1

}

env_backup_destination_is_inside_root() {

    local root="$1"
    local dest="$2"
    local root_real=""
    local parent=""
    local parent_real=""

    [ -d "$root" ] || return 1

    root_real=$(cd "$root" && pwd -P)
    parent=$(env_backup_dirname "$dest")

    if [ ! -d "$parent" ]; then
        case "$dest" in
            "$root"/*|"$root_real"/*)
                return 0
                ;;
        esac
        return 1
    fi

    parent_real=$(cd "$parent" && pwd -P)

    case "$parent_real" in
        "$root_real"|"$root_real"/*)
            ;;
        *)
            return 1
            ;;
    esac

    if [ -L "$dest" ]; then
        return 1
    fi

    if [ -e "$dest" ]; then
        case "$(env_backup_realpath "$dest")" in
            "$root_real"/*)
                return 0
                ;;
        esac
        return 1
    fi

    return 0

}

env_backup_cmd_restore() {

    local dry=0
    local force=0
    local filter=""
    local snapshot_arg=""
    local snapshot=""
    local stage=""
    local payload=""
    local namespace=""
    local rel=""
    local hash=""
    local mtime=""
    local root=""
    local dest=""
    local src=""
    local actual=""
    local action=""
    local bak=""
    local stamp=""
    local matched=0
    local restored=0
    local skipped_same=0
    local skipped_newer=0
    local replaced=0
    local local_mtime=0

    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                dry=1
                ;;
            --force)
                force=1
                ;;
            --path)
                shift
                [ $# -gt 0 ] || env_backup_die "--path needs a value"
                filter="$1"
                ;;
            --latest)
                snapshot_arg=""
                ;;
            -*)
                env_backup_die "unknown argument: $1"
                ;;
            *)
                snapshot_arg="$1"
                ;;
        esac
        shift
    done

    snapshot=$(env_backup_resolve_snapshot "$snapshot_arg")
    stage=$(env_backup_mktmp)
    env_backup_decrypt_snapshot "$snapshot" "$stage"
    payload="$stage/out/payload"
    stamp=$(env_backup_now_stamp)

    while IFS="$(printf '\t')" read -r namespace rel hash mtime; do
        [ -n "$namespace" ] || continue
        env_backup_path_selected "$namespace" "$rel" "$filter" || continue
        matched=$((matched + 1))

        root=$(env_backup_root_path_by_name "$namespace") || {
            printf 'skip\t%s\t%s\tunknown-root\n' "$namespace" "$rel"
            continue
        }

        if [ ! -d "$root" ]; then
            printf 'skip\t%s\t%s\troot-missing\n' "$namespace" "$rel"
            continue
        fi

        dest="$root/$rel"
        src="$payload/$namespace/$rel"

        [ -f "$src" ] || env_backup_die "payload missing for $namespace/$rel"

        actual=$(env_backup_sha256_file "$src")
        [ "$actual" = "$hash" ] || env_backup_die "checksum mismatch for $namespace/$rel"

        if [ -L "$dest" ]; then
            printf 'skip\t%s\t%s\tsymlink\n' "$namespace" "$rel"
            continue
        fi

        if ! env_backup_destination_is_inside_root "$root" "$dest"; then
            printf 'skip\t%s\t%s\toutside-root\n' "$namespace" "$rel"
            continue
        fi

        if [ ! -e "$dest" ]; then
            action="create"
        elif cmp -s -- "$src" "$dest"; then
            action="identical"
        else
            local_mtime=$(env_backup_mtime "$dest")
            if [ "$local_mtime" -gt "$mtime" ] && [ "$force" -ne 1 ]; then
                action="newer"
            else
                action="replace"
            fi
        fi

        case "$action" in
            identical)
                skipped_same=$((skipped_same + 1))
                printf 'skip\t%s\t%s\tidentical\n' "$namespace" "$rel"
                ;;
            newer)
                skipped_newer=$((skipped_newer + 1))
                printf 'skip\t%s\t%s\tnewer-local\n' "$namespace" "$rel"
                ;;
            create|replace)
                if [ "$dry" -eq 1 ]; then
                    printf 'would-%s\t%s\t%s\t%s\n' "$action" "$namespace" "$rel" "$dest"
                    continue
                fi

                command mkdir -p -- "$(env_backup_dirname "$dest")"

                if [ "$action" = "replace" ]; then
                    bak="${dest}.env-backup-bak-${stamp}-$$"
                    command cp -- "$dest" "$bak"
                    command chmod 600 "$bak"
                    replaced=$((replaced + 1))
                    printf 'backed-up\t%s\n' "$bak"
                else
                    restored=$((restored + 1))
                fi

                command cp -- "$src" "$dest"
                command chmod 600 "$dest"
                env_backup_touch_mtime "$mtime" "$dest" || true
                printf 'restored\t%s\t%s\t%s\n' "$namespace" "$rel" "$dest"
                ;;
        esac
    done << EOF
$(env_backup_manifest_rows "$stage/out/manifest.tsv")
EOF

    if [ -n "$filter" ] && [ "$matched" -eq 0 ]; then
        env_backup_die "no snapshot paths match --path $filter"
    fi

    printf 'summary\tmatched=%s\trestored_or_created=%s\treplaced=%s\tidentical=%s\tnewer=%s\tdry_run=%s\n' \
        "$matched" "$restored" "$replaced" "$skipped_same" "$skipped_newer" "$dry"

}

env_backup_cmd_prune() {

    local dry=0
    local names=""
    local keep=""
    local base=""
    local file=""
    local deleted=0

    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                dry=1
                ;;
            *)
                env_backup_die "unknown argument: $1"
                ;;
        esac
        shift
    done

    if [ ! -d "$ENV_BACKUP_DIR" ]; then
        [ "$dry" -eq 1 ] && return 0
        env_backup_log "prune: backup folder is not available"
        return 0
    fi

    if [ "$dry" -eq 0 ]; then
        env_backup_clean_partials
    fi

    names=$(env_backup_list_snapshot_files | while IFS= read -r file; do
        [ -n "$file" ] || continue
        env_backup_basename "$file"
    done)

    [ -n "$names" ] || return 0

    keep=$(printf '%s\n' "$names" | env_backup_plan_retention \
        "$ENV_BACKUP_KEEP_RECENT" \
        "$ENV_BACKUP_KEEP_DAILY" \
        "$ENV_BACKUP_KEEP_MONTHLY")

    while IFS= read -r base; do
        [ -n "$base" ] || continue

        if env_backup_keep_has "$keep" "$base"; then
            continue
        fi

        if [ "$dry" -eq 1 ]; then
            printf 'would delete %s\n' "$base"
        else
            command rm -f -- "$ENV_BACKUP_DIR/$base"
            env_backup_log "deleted $base"
        fi
        deleted=$((deleted + 1))
    done << EOF
$names
EOF

    if [ "$dry" -eq 1 ]; then
        printf 'would delete %s snapshot(s)\n' "$deleted"
    fi

}

env_backup_migrate_rels() {

    local rel="$1"
    local part=""
    local i=0
    local known=0
    local j=0
    local n=0

    printf '%s\n' "$rel"

    n=$(env_backup_root_index_count)

    while [ "$i" -lt 3 ]; do
        part=${rel%%/*}
        [ "$part" != "$rel" ] || break

        known=0

        case "$part" in
            projects|home|adata)
                known=1
                ;;
        esac

        j=0

        while [ "$j" -lt "$n" ]; do
            if [ "${ROOT_NAMES[$j]}" = "$part" ]; then
                known=1
            fi
            j=$((j + 1))
        done

        [ "$known" -eq 1 ] || break

        rel=${rel#*/}
        printf '%s\n' "$rel"
        i=$((i + 1))
    done

}

env_backup_cmd_migrate() {

    local apply=0
    local force=0
    local root_filter=""
    local path_filter=""
    local vault=""
    local work=""
    local list=""
    local namespace=""
    local rel=""
    local path=""
    local candidate=""
    local i=0
    local n=0
    local dest=""
    local matches=""
    local match_count=0
    local chosen_ns=""
    local chosen_dest=""
    local stamp=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --apply)
                apply=1
                ;;
            --dry-run)
                apply=0
                ;;
            --force)
                force=1
                ;;
            --root)
                shift
                [ $# -gt 0 ] || env_backup_die "--root needs a value"
                root_filter="$1"
                ;;
            --path)
                shift
                [ $# -gt 0 ] || env_backup_die "--path needs a value"
                path_filter="$1"
                ;;
            *)
                env_backup_die "unknown argument: $1"
                ;;
        esac
        shift
    done

    vault="$ENV_BACKUP_VAULT"

    if [ ! -d "$vault" ]; then
        env_backup_log "Cryptomator vault is not mounted at $vault"
        env_backup_log "Unlock DotEnvs and rerun env-backup migrate, or back up the project trees directly."
        exit 0
    fi

    work=$(env_backup_mktmp)
    list="$work/files.tsv"
    : > "$list"
    env_backup_scan_root "vault" "$vault" "$list"
    stamp=$(env_backup_now_stamp)
    n=$(env_backup_root_index_count)

    if [ ! -s "$list" ]; then
        printf '%s\n' "no secret files in $vault"
        return 0
    fi

    while IFS="$(printf '\t')" read -r namespace rel path; do
        [ -n "$rel" ] || continue

        if [ -n "$path_filter" ]; then
            case "$rel" in
                "$path_filter"|"$path_filter"/*)
                    ;;
                *)
                    continue
                    ;;
            esac
        fi

        matches=""
        match_count=0

        while IFS= read -r candidate; do
            [ -n "$candidate" ] || continue
            i=0

            while [ "$i" -lt "$n" ]; do
                if [ -n "$root_filter" ] && [ "${ROOT_NAMES[$i]}" != "$root_filter" ]; then
                    i=$((i + 1))
                    continue
                fi

                if [ ! -d "${ROOT_PATHS[$i]}" ]; then
                    i=$((i + 1))
                    continue
                fi

                dest="${ROOT_PATHS[$i]}/$candidate"

                if [ -d "$(env_backup_dirname "$dest")" ]; then
                    matches="${matches}${ROOT_NAMES[$i]}"$'\t'"$dest"$'\n'
                    match_count=$((match_count + 1))
                fi

                i=$((i + 1))
            done
        done << EOF
$(env_backup_migrate_rels "$rel")
EOF

        if [ "$match_count" -eq 0 ]; then
            printf 'skip\t%s\tno-project-dir\n' "$rel"
            continue
        fi

        if [ "$match_count" -gt 1 ]; then
            printf 'skip\t%s\tambiguous\n' "$rel"
            printf '%s' "$matches" | while IFS="$(printf '\t')" read -r chosen_ns chosen_dest; do
                [ -n "$chosen_dest" ] || continue
                printf 'candidate\t%s\t%s\n' "$chosen_ns" "$chosen_dest"
            done
            continue
        fi

        chosen_ns=${matches%%$'\t'*}
        chosen_dest=${matches#*$'\t'}
        chosen_dest=${chosen_dest%$'\n'}

        if [ -L "$chosen_dest" ]; then
            printf 'skip\t%s\tsymlink\n' "$rel"
            continue
        fi

        if [ -e "$chosen_dest" ] && cmp -s -- "$path" "$chosen_dest"; then
            printf 'skip\t%s\tidentical\t%s\n' "$rel" "$chosen_dest"
            continue
        fi

        if [ -e "$chosen_dest" ] && [ "$force" -ne 1 ]; then
            printf 'skip\t%s\tdiffers\t%s\n' "$rel" "$chosen_dest"
            continue
        fi

        if [ "$apply" -ne 1 ]; then
            if [ -e "$chosen_dest" ]; then
                printf 'would-replace\t%s\t%s\t%s\n' "$chosen_ns" "$rel" "$chosen_dest"
            else
                printf 'would-copy\t%s\t%s\t%s\n' "$chosen_ns" "$rel" "$chosen_dest"
            fi
            continue
        fi

        if ! env_backup_destination_is_inside_root "$(env_backup_root_path_by_name "$chosen_ns")" "$chosen_dest"; then
            printf 'skip\t%s\toutside-root\n' "$rel"
            continue
        fi

        if [ -e "$chosen_dest" ]; then
            command cp -- "$chosen_dest" "${chosen_dest}.env-backup-bak-${stamp}-$$"
            command chmod 600 "${chosen_dest}.env-backup-bak-${stamp}-$$"
        fi

        command mkdir -p -- "$(env_backup_dirname "$chosen_dest")"
        command cp -- "$path" "$chosen_dest"
        command chmod 600 "$chosen_dest"
        printf 'copied\t%s\t%s\t%s\n' "$chosen_ns" "$rel" "$chosen_dest"
    done < "$list"

    if [ "$apply" -ne 1 ]; then
        printf '%s\n' "dry-run only. Re-run with --apply to copy files into the project trees."
    fi

}

env_backup_bash_path() {

    if [ -n "${ENV_BACKUP_BASH:-}" ] && [ -x "$ENV_BACKUP_BASH" ]; then
        printf '%s\n' "$ENV_BACKUP_BASH"
        return 0
    fi

    if [ -x /opt/homebrew/bin/bash ]; then
        printf '%s\n' "/opt/homebrew/bin/bash"
        return 0
    fi

    if [ -x /usr/local/bin/bash ]; then
        printf '%s\n' "/usr/local/bin/bash"
        return 0
    fi

    command -v bash

}

env_backup_xml_escape() {

    local value="$1"

    value=${value//&/&amp;}
    value=${value//</&lt;}
    value=${value//>/&gt;}
    printf '%s' "$value"

}

env_backup_render_plist() {

    local template="$1"
    local bash_path=""
    local script_path=""
    local home_xml=""
    local line=""

    bash_path=$(env_backup_xml_escape "$(env_backup_bash_path)")
    script_path=$(env_backup_xml_escape "$ENV_BACKUP_BIN_DIR/env-backup")
    home_xml=$(env_backup_xml_escape "$HOME")
    [ -f "$template" ] || env_backup_die "missing plist template: $template"
    [ -n "$bash_path" ] || env_backup_die "could not find bash"

    while IFS= read -r line || [ -n "$line" ]; do
        line=${line//@@HOME@@/$home_xml}
        line=${line//@@BASH@@/$bash_path}
        line=${line//@@SCRIPT@@/$script_path}
        line=${line//@@LABEL@@/$ENV_BACKUP_AGENT_LABEL}
        printf '%s\n' "$line"
    done < "$template"

}

env_backup_cmd_install_agent() {

    local print_only=0
    local template=""
    local target=""
    local uid=""
    local rendered=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --print)
                print_only=1
                ;;
            *)
                env_backup_die "unknown argument: $1"
                ;;
        esac
        shift
    done

    [ -n "${ENV_BACKUP_BIN_DIR:-}" ] || env_backup_die "ENV_BACKUP_BIN_DIR is not set"
    template="$ENV_BACKUP_BIN_DIR/../os/launchd/com.gfelizola.env-backup.plist.template"

    if [ "$print_only" -eq 1 ]; then
        env_backup_render_plist "$template"
        return 0
    fi

    [ "$(uname)" = "Darwin" ] || env_backup_die "LaunchAgents are macOS-only"
    command -v launchctl > /dev/null 2>&1 || env_backup_die "launchctl is not available"

    target="$HOME/Library/LaunchAgents/$ENV_BACKUP_AGENT_LABEL.plist"
    command mkdir -p -- "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

    rendered=$(env_backup_mktmp)/agent.plist
    env_backup_render_plist "$template" > "$rendered"

    uid=$(id -u)

    if [ -f "$target" ]; then
        launchctl bootout "gui/$uid" "$target" > /dev/null 2>&1 || \
            launchctl unload -w "$target" > /dev/null 2>&1 || true
    fi

    command cp -- "$rendered" "$target"
    command chmod 644 "$target"

    if ! launchctl bootstrap "gui/$uid" "$target" > /dev/null 2>&1; then
        launchctl load -w "$target"
    fi

    printf '%s\n' "installed $target"
    printf '%s\n' "logs: $HOME/Library/Logs/env-backup.log"

}

env_backup_cmd_uninstall_agent() {

    local target=""
    local uid=""

    [ "$(uname)" = "Darwin" ] || env_backup_die "LaunchAgents are macOS-only"

    target="$HOME/Library/LaunchAgents/$ENV_BACKUP_AGENT_LABEL.plist"
    uid=$(id -u)

    if command -v launchctl > /dev/null 2>&1 && [ -f "$target" ]; then
        launchctl bootout "gui/$uid" "$target" > /dev/null 2>&1 || \
            launchctl unload -w "$target" > /dev/null 2>&1 || true
    fi

    command rm -f -- "$target"
    printf '%s\n' "removed $target"

}

env_backup_cmd() {

    local cmd="${1:-help}"

    if [ $# -gt 0 ]; then
        shift
    fi

    case "$cmd" in
        setup)
            env_backup_cmd_setup "$@"
            ;;
        import-identity)
            env_backup_cmd_import_identity "$@"
            ;;
        export-identity)
            env_backup_cmd_export_identity "$@"
            ;;
        backup)
            env_backup_cmd_backup "$@"
            ;;
        status)
            env_backup_cmd_status "$@"
            ;;
        list)
            env_backup_cmd_list "$@"
            ;;
        show)
            env_backup_cmd_show "$@"
            ;;
        diff)
            env_backup_cmd_diff "$@"
            ;;
        restore)
            env_backup_cmd_restore "$@"
            ;;
        prune)
            env_backup_cmd_prune "$@"
            ;;
        migrate)
            env_backup_cmd_migrate "$@"
            ;;
        install-agent)
            env_backup_cmd_install_agent "$@"
            ;;
        uninstall-agent)
            env_backup_cmd_uninstall_agent "$@"
            ;;
        help|-h|--help)
            env_backup_cmd_help
            ;;
        *)
            env_backup_cmd_help >&2
            env_backup_die "unknown command: $cmd"
            ;;
    esac

}
