#!/usr/bin/env bash

# Exercises env-backup without the macOS keychain.
# Identity material stays under the temp directory.

set -eo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$ROOT/src/bin/env-backup"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/env-backup-test.XXXXXX")"

export HOME="$BASE/home"
export TMPDIR="$BASE/tmp"
export ENV_BACKUP_CONFIG_DIR="$BASE/config"
export ENV_BACKUP_DIR="$BASE/drive"
export ENV_BACKUP_LOG_FILE="-"
export ENV_BACKUP_ALLOW_IDENTITY_FILE=1
export ENV_BACKUP_IDENTITY_FILE="$BASE/identity"
export ENV_BACKUP_SETUP_QUIET=1
export ENV_BACKUP_KEEP_RECENT=3
export ENV_BACKUP_KEEP_DAILY=14
export ENV_BACKUP_KEEP_MONTHLY=12

mkdir -p "$HOME" "$TMPDIR" "$ENV_BACKUP_CONFIG_DIR" "$ENV_BACKUP_DIR"

cleanup_suite() {
    rm -rf "$BASE"
}

trap cleanup_suite EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_eq() {
    if [ "$1" != "$2" ]; then
        fail "${3:-values differ}: expected [$2] got [$1]"
    fi
}

file_mode() {
    if stat -c %a "$1" > /dev/null 2>&1; then
        stat -c %a "$1"
    else
        stat -f %OLp "$1"
    fi
}

snapshot_count() {
    find "$ENV_BACKUP_DIR" -maxdepth 1 -type f -name 'dotenv-*.age' | wc -l | tr -d ' '
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# shellcheck source=src/bin/env-backup-lib.sh
. "$ROOT/src/bin/env-backup-lib.sh"

export ENV_BACKUP_ROOTS="home|$BASE/unused"
env_backup_configure

for included in \
    .env \
    .env.local \
    .env.fallback \
    .env.evidence \
    .env.emulator \
    .env.bkp \
    .env.development \
    .env.production \
    .env.test \
    .env.production.local \
    .envrc \
    .dev.vars
do
    env_backup_name_included "$included" || fail "should include $included"
done

for excluded in \
    .env.example \
    .env.sample \
    .env.template \
    .env.dist \
    .env.local.example \
    .env.example.local \
    .dev.vars.example \
    notes.txt
do
    if env_backup_name_included "$excluded"; then
        fail "should exclude $excluded"
    fi
done

retention_input="$(cat << 'EOF'
dotenv-20261119T180000Z.age
dotenv-20261119T120000Z.age
dotenv-20261119T090000Z.age
dotenv-20261118T180000Z.age
dotenv-20261117T180000Z.age
dotenv-20261116T180000Z.age
dotenv-20261015T180000Z.age
dotenv-20260901T180000Z.age
dotenv-20260115T180000Z.age
dotenv-20250101T180000Z.age
EOF
)"

retention_got="$(printf '%s\n' "$retention_input" | env_backup_plan_retention 2 3 2 | LC_ALL=C sort)"
retention_want="$(printf '%s\n' \
    dotenv-20261015T180000Z.age \
    dotenv-20261117T180000Z.age \
    dotenv-20261118T180000Z.age \
    dotenv-20261119T120000Z.age \
    dotenv-20261119T180000Z.age | LC_ALL=C sort)"

assert_eq "$retention_got" "$retention_want" "retention plan"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if ENV_BACKUP_IDENTITY_FILE="$ROOT/identity.txt" "$BIN" setup > "$BASE/setup-refused.txt" 2> "$BASE/setup-refused.err"; then
    fail "setup should refuse an identity path inside the repo"
fi

if [ -e "$ROOT/identity.txt" ]; then
    rm -f "$ROOT/identity.txt"
    fail "setup wrote an identity into the repo"
fi

grep -q "dotfiles repo" "$BASE/setup-refused.err" || fail "missing repo refusal message"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

PROJ="$BASE/projects"
ADATA="$BASE/adata"
VAULT="$BASE/vault"
MARKER="SUPERSECRET-MARKER-env-backup-$$"

mkdir -p \
    "$PROJ/client/app" \
    "$PROJ/my project" \
    "$PROJ/empty/node_modules/pkg" \
    "$PROJ/empty/dist" \
    "$PROJ/empty/build" \
    "$PROJ/empty/.next" \
    "$PROJ/empty/.git" \
    "$ADATA/client/app" \
    "$ADATA/other" \
    "$VAULT/client/app"

printf '%s\n' "$MARKER home" > "$PROJ/client/app/.env"
printf '%s\n' "local" > "$PROJ/client/app/.env.local"
printf '%s\n' "fallback" > "$PROJ/client/app/.env.fallback"
printf '%s\n' "evidence" > "$PROJ/client/app/.env.evidence"
printf '%s\n' "emulator" > "$PROJ/client/app/.env.emulator"
printf '%s\n' "bkp" > "$PROJ/client/app/.env.bkp"
printf '%s\n' "development" > "$PROJ/client/app/.env.development"
printf '%s\n' "production" > "$PROJ/client/app/.env.production"
printf '%s\n' "test" > "$PROJ/client/app/.env.test"
printf '%s\n' "prodlocal" > "$PROJ/client/app/.env.production.local"
printf '%s\n' "devvars" > "$PROJ/client/app/.dev.vars"
printf '%s\n' "space" > "$PROJ/my project/.env"
printf '%s\n' "example" > "$PROJ/client/app/.env.example"
printf '%s\n' "sample" > "$PROJ/client/app/.env.sample"
printf '%s\n' "template" > "$PROJ/client/app/.env.template"
printf '%s\n' "distfile" > "$PROJ/client/app/.env.dist"
printf '%s\n' "local-example" > "$PROJ/client/app/.env.local.example"
printf '%s\n' "example-local" > "$PROJ/client/app/.env.example.local"
printf '%s\n' "nested" > "$PROJ/empty/node_modules/pkg/.env"
printf '%s\n' "dist" > "$PROJ/empty/dist/.env"
printf '%s\n' "build" > "$PROJ/empty/build/.env"
printf '%s\n' "next" > "$PROJ/empty/.next/.env"
printf '%s\n' "gitdir" > "$PROJ/empty/.git/.env"
printf '%s\n' "$MARKER adata" > "$ADATA/client/app/.env"
printf '%s\n' "other" > "$ADATA/other/.env.fallback"
printf '%s\n' "from-vault" > "$VAULT/client/app/.env"

export ENV_BACKUP_ROOTS="home|$PROJ
adata|$ADATA"
export ENV_BACKUP_VAULT="$VAULT"

"$BIN" setup > "$BASE/setup.out"
grep -q '^recipient age1' "$BASE/setup.out" || fail "setup did not record a recipient"
[ "$(file_mode "$ENV_BACKUP_IDENTITY_FILE")" = "600" ] || fail "identity file mode is not 600"
recipient_path="$ENV_BACKUP_CONFIG_DIR/recipient"
grep -q '^age1' "$recipient_path" || fail "recipient file missing"

# Refuse a backup whose identity would land in Drive.
if ENV_BACKUP_IDENTITY_FILE="$ENV_BACKUP_DIR/key.txt" "$BIN" import-identity < "$BASE/identity" > /dev/null 2> "$BASE/import-drive.err"; then
    fail "import should refuse Drive"
fi
grep -q "backup folder" "$BASE/import-drive.err" || fail "missing Drive refusal"

if "$BIN" export-identity > "$ENV_BACKUP_DIR/leaked-key.txt" 2> "$BASE/export-drive.err"; then
    rm -f "$ENV_BACKUP_DIR/leaked-key.txt"
    fail "export-identity should refuse the backup folder"
fi
rm -f "$ENV_BACKUP_DIR/leaked-key.txt"
grep -q "backup folder" "$BASE/export-drive.err" || fail "export-identity did not explain the refusal"
if [ -f "$ENV_BACKUP_DIR/leaked-key.txt" ] && grep -q 'AGE-SECRET-KEY-' "$ENV_BACKUP_DIR/leaked-key.txt"; then
    fail "export-identity wrote the private key into the backup folder"
fi

dry="$("$BIN" backup --dry-run)"
printf '%s\n' "$dry" | grep -q 'include	home	client/app/.env' || fail "dry-run missed home .env"
printf '%s\n' "$dry" | grep -q 'include	adata	client/app/.env' || fail "dry-run missed adata .env"
printf '%s\n' "$dry" | grep -q 'include	home	my project/.env' || fail "dry-run missed spaced path"
printf '%s\n' "$dry" | grep -q 'include	home	client/app/.env.evidence' || fail "dry-run missed .env.evidence"
printf '%s\n' "$dry" | grep -q 'include	home	client/app/.dev.vars' || fail "dry-run missed .dev.vars"
printf '%s\n' "$dry" | grep -q 'would write a snapshot' || fail "dry-run should want a snapshot"
if printf '%s\n' "$dry" | grep -q 'node_modules\|/\.git/\|empty/dist\|empty/build\|empty/.next\|\.example\|\.sample\|\.template\|\.dist'; then
    fail "dry-run included a pruned or template file: $dry"
fi
[ "$(snapshot_count)" = "0" ] || fail "dry-run wrote a snapshot"

ENV_BACKUP_NOW=20261119T120000Z "$BIN" backup > "$BASE/backup1.log"
grep -q 'wrote dotenv-20261119T120000Z.age' "$BASE/backup1.log" || fail "first backup did not write"
[ "$(snapshot_count)" = "1" ] || fail "expected 1 snapshot"

leaked="$(find "$ENV_BACKUP_DIR" -type f ! -name '*.age' -exec grep -F -l "$MARKER" {} + 2> /dev/null || true)"
[ -z "$leaked" ] || fail "plaintext marker leaked into the backup folder: $leaked"

leaked="$(find "$TMPDIR" -type f -exec grep -F -l "$MARKER" {} + 2> /dev/null || true)"
[ -z "$leaked" ] || fail "plaintext marker leaked into TMPDIR: $leaked"

left="$(find "$TMPDIR" -name 'env-backup.*' -print)"
[ -z "$left" ] || fail "temp dir left behind: $left"

show="$("$BIN" show)"
printf '%s\n' "$show" | grep -q 'home	client/app/.env' || fail "show missed home file"
printf '%s\n' "$show" | grep -q 'adata	client/app/.env' || fail "show missed adata file"
if printf '%s\n' "$show" | grep -q "$MARKER"; then
    fail "show printed secret contents"
fi

ENV_BACKUP_NOW=20261119T120100Z "$BIN" backup > "$BASE/backup-same.log"
grep -q 'unchanged' "$BASE/backup-same.log" || fail "identical backup should be unchanged"
[ "$(snapshot_count)" = "1" ] || fail "unchanged backup wrote a snapshot"

touch -d @1000000000 "$PROJ/client/app/.env" 2> /dev/null || touch -t 200109090000 "$PROJ/client/app/.env"
ENV_BACKUP_NOW=20261119T120200Z "$BIN" backup > "$BASE/backup-mtime.log"
grep -q 'unchanged' "$BASE/backup-mtime.log" || fail "mtime-only change should be unchanged"

printf '%s\n' "$MARKER changed" > "$PROJ/client/app/.env"
ENV_BACKUP_NOW=20261119T130000Z "$BIN" backup > "$BASE/backup2.log"
[ "$(snapshot_count)" = "2" ] || fail "content change should write a second snapshot"

status="$("$BIN" status)"
printf '%s\n' "$status" | grep -q 'home  '"$PROJ"'  ' || fail "status missing home count"
printf '%s\n' "$status" | grep -q 'nothing new or changed' || fail "status should be clean after backup"

diff_out="$("$BIN" diff dotenv-20261119T120000Z.age)"
printf '%s\n' "$diff_out" | grep -q '~	home	client/app/.env	changed' || fail "diff missed the edit"

# Newer local file is kept unless --force.
printf '%s\n' "newer-local-value" > "$PROJ/client/app/.env.local"
touch -d @2000000000 "$PROJ/client/app/.env.local" 2> /dev/null || touch -t 203301010000 "$PROJ/client/app/.env.local"
restore_skip="$("$BIN" restore --path client/app/.env.local)"
printf '%s\n' "$restore_skip" | grep -q 'newer-local' || fail "restore should skip a newer file"
grep -q 'newer-local-value' "$PROJ/client/app/.env.local" || fail "newer file was overwritten"

restore_force="$("$BIN" restore --force --path client/app/.env.local)"
printf '%s\n' "$restore_force" | grep -q 'restored	home	client/app/.env.local' || fail "force restore failed"
grep -q 'local' "$PROJ/client/app/.env.local" || fail "force restore did not write the snapshot"
find "$PROJ/client/app" -name '.env.local.env-backup-bak-*' | grep -q . || fail "force restore did not keep a local copy"
[ "$(file_mode "$PROJ/client/app/.env.local")" = "600" ] || fail "restored file is not mode 600"

# Subset restore does not touch the other project.
printf '%s\n' "space-mutated" > "$PROJ/my project/.env"
printf '%s\n' "app-mutated" > "$PROJ/client/app/.env.fallback"
# Make them older than the snapshot so restore will replace them.
touch -d @1000 "$PROJ/my project/.env" "$PROJ/client/app/.env.fallback" 2> /dev/null || true
"$BIN" restore --path "my project" > "$BASE/restore-space.txt"
grep -q 'space' "$PROJ/my project/.env" || fail "spaced path was not restored"
grep -q 'app-mutated' "$PROJ/client/app/.env.fallback" || fail "subset restore touched another file"

# Missing root must not publish a partial snapshot.
hidden="$ADATA.hidden"
mv "$ADATA" "$hidden"
set +e
ENV_BACKUP_NOW=20261119T150000Z "$BIN" backup --unattended > "$BASE/partial.log"
partial_status=$?
set -e
[ "$partial_status" -eq 0 ] || fail "missing root should exit 0, got $partial_status"
grep -q 'not writing a snapshot' "$BASE/partial.log" || fail "missing root should refuse the snapshot"
[ "$(snapshot_count)" = "2" ] || fail "refused backup still wrote a snapshot"
mv "$hidden" "$ADATA"

# Drive absent.
missing_drive="$HOME/Library/CloudStorage/GoogleDrive-missing@example.com/My Drive/Backups/dotenv"
set +e
ENV_BACKUP_DIR="$missing_drive" "$BIN" backup --unattended > "$BASE/nodrive.log"
nodrive_status=$?
set -e
[ "$nodrive_status" -eq 0 ] || fail "missing Drive should exit 0"
[ ! -d "$HOME/Library/CloudStorage" ] || fail "backup created a fake CloudStorage directory"
grep -q 'not available' "$BASE/nodrive.log" || fail "missing Drive should be logged"

# Same-day retention collapses to the newest snapshot when N is 1.
ENV_BACKUP_KEEP_RECENT=1 ENV_BACKUP_KEEP_DAILY=1 ENV_BACKUP_KEEP_MONTHLY=1 \
    ENV_BACKUP_NOW=20261119T160000Z "$BIN" backup > "$BASE/prune.log"
[ "$(snapshot_count)" = "1" ] || fail "prune should keep only the newest snapshot, have $(snapshot_count)"
[ -f "$ENV_BACKUP_DIR/dotenv-20261119T160000Z.age" ] || fail "prune deleted the newest snapshot"

# Reset retention for the remaining checks by starting a fresh drive.
rm -rf "$ENV_BACKUP_DIR"
mkdir -p "$ENV_BACKUP_DIR"
rm -f "$ENV_BACKUP_DIR/state"
export ENV_BACKUP_KEEP_RECENT=3
export ENV_BACKUP_KEEP_DAILY=14
export ENV_BACKUP_KEEP_MONTHLY=12

# Migrate from the old vault is dry-run unless --apply.
# Use a project directory that does not yet have the secret file.
mkdir -p "$PROJ/from-vault"
rm -rf "$VAULT"
mkdir -p "$VAULT/from-vault"
printf '%s\n' "vault-secret" > "$VAULT/from-vault/.env"
migrate="$("$BIN" migrate --path from-vault)"
printf '%s\n' "$migrate" | grep -q 'would-copy	home	from-vault/.env' || fail "migrate did not match from-vault: $migrate"
[ ! -f "$PROJ/from-vault/.env" ] || fail "migrate dry-run wrote a file"
"$BIN" migrate --apply --path from-vault > "$BASE/migrate-apply.txt"
grep -q 'vault-secret' "$PROJ/from-vault/.env" || fail "migrate --apply did not copy"
[ "$(file_mode "$PROJ/from-vault/.env")" = "600" ] || fail "migrated file is not mode 600"

# LaunchAgent plist renders without launchctl.
plist="$("$BIN" install-agent --print)"
printf '%s\n' "$plist" | grep -q '<key>StartOnMount</key>' || fail "plist missing StartOnMount"
printf '%s\n' "$plist" | grep -q '/Volumes/ADATA-GFELIZOLA' || fail "plist missing ADATA watch"
printf '%s\n' "$plist" | grep -q 'backup' || fail "plist missing backup command"
printf '%s\n' "$plist" | grep -q -- '--unattended' || fail "plist missing --unattended"
printf '%s\n' "$plist" | grep -q 'Library/Logs/env-backup.log' || fail "plist missing log path"
printf '%s\n' "$plist" | grep -q "$BIN" || fail "plist missing script path"

# Deprecated names still dispatch.
env_status_out="$("$ROOT/src/bin/env-status" 2> "$BASE/deprecated.txt")"
grep -q 'deprecated' "$BASE/deprecated.txt" || fail "env-status should warn"
printf '%s\n' "$env_status_out" | grep -q 'destination:' || fail "env-status did not run status"

printf '%s\n' "ok"
