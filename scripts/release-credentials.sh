#!/bin/bash
# Keep release settings in the macOS login keychain instead of files or shell history.
# scripts/release.sh reads them automatically (environment variables still win).
#
#   scripts/release-credentials.sh set            ask for every value and store it
#   scripts/release-credentials.sh set NAME       ask for one value
#   scripts/release-credentials.sh status         show which values are stored (never the values)
#   scripts/release-credentials.sh delete NAME    remove one value
#
# Names (stored as keychain items "<KEYCHAIN_PREFIX>-release-<NAME>", the prefix is set in Config/release.conf):
#   R2_ENDPOINT  R2_BUCKET  R2_ACCESS_KEY_ID  R2_SECRET_ACCESS_KEY  SIGN_IDENTITY  NOTARY_PROFILE
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
CONF="${RELEASE_CONF:-Config/release.conf}"
[[ -f "$CONF" ]] || { printf 'error: %s not found\n' "$CONF" >&2; exit 1; }
KEYCHAIN_PREFIX="$(source "$CONF" && printf '%s' "${KEYCHAIN_PREFIX:-}")"
[[ -n "$KEYCHAIN_PREFIX" ]] || { printf 'error: KEYCHAIN_PREFIX is not set in %s\n' "$CONF" >&2; exit 1; }

NAMES=(R2_ENDPOINT R2_BUCKET R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY SIGN_IDENTITY NOTARY_PROFILE)
SECRET=(R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY)

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
valid_name() { local n; for n in "${NAMES[@]}"; do [[ "$n" == "$1" ]] && return 0; done; return 1; }
is_secret() { local n; for n in "${SECRET[@]}"; do [[ "$n" == "$1" ]] && return 0; done; return 1; }
service() { printf '%s-release-%s' "$KEYCHAIN_PREFIX" "$1"; }

hint() {
  case "$1" in
    R2_ENDPOINT) echo "https://<account-id>.r2.cloudflarestorage.com (R2 > Manage API tokens)" ;;
    R2_BUCKET) echo "bucket name, e.g. $KEYCHAIN_PREFIX-downloads" ;;
    R2_ACCESS_KEY_ID) echo "from the R2 API token page (shown once)" ;;
    R2_SECRET_ACCESS_KEY) echo "from the R2 API token page (shown once)" ;;
    SIGN_IDENTITY) echo 'e.g. Developer ID Application: Your Name (TEAMID)' ;;
    NOTARY_PROFILE) echo "name given to: xcrun notarytool store-credentials <name>" ;;
  esac
}

# Catch the usual mix-ups before storing (never prints the value).
check_format() {
  local name="$1" value="$2"
  case "$name" in
    R2_ENDPOINT)
      [[ "$value" =~ ^https://[A-Za-z0-9]+(\.[a-z]+)?\.r2\.cloudflarestorage\.com/?$ ]] \
        || die "R2_ENDPOINT must look like https://<account-id>.r2.cloudflarestorage.com (not the token value)" ;;
    R2_ACCESS_KEY_ID | R2_SECRET_ACCESS_KEY)
      if [[ "$value" == cf[a-z][a-z]_* ]]; then
        die "$name looks like a Cloudflare API token value (cf..._...). Use the S3 Access Key ID / Secret Access Key shown on the same page"
      fi
      [[ "$value" =~ ^[0-9a-f]+$ ]] || die "$name should be hexadecimal (check you copied the right field)" ;;
  esac
}

store() {
  local name="$1" value
  valid_name "$name" || die "unknown name: $name"
  if is_secret "$name"; then
    read -r -s -p "$name ($(hint "$name")): " value; echo
  else
    read -r -p "$name ($(hint "$name")): " value
  fi
  [[ -n "$value" ]] || die "empty value, nothing stored"
  check_format "$name" "$value"
  security add-generic-password -a "$USER" -s "$(service "$name")" -w "$value" -U \
    || die "could not write to the keychain"
  echo "stored $name"
}

case "${1:-}" in
  set)
    if [[ -n "${2:-}" ]]; then store "$2"; else for n in "${NAMES[@]}"; do store "$n"; done; fi ;;
  status)
    for n in "${NAMES[@]}"; do
      if security find-generic-password -a "$USER" -s "$(service "$n")" > /dev/null 2>&1; then
        printf '%-22s stored\n' "$n"
      else
        printf '%-22s -\n' "$n"
      fi
    done ;;
  delete)
    valid_name "${2:-}" || die "usage: delete <NAME>"
    security delete-generic-password -a "$USER" -s "$(service "$2")" > /dev/null || die "not found: $2"
    echo "deleted $2" ;;
  *) awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"; exit 64 ;;
esac
