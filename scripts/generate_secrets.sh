#!/usr/bin/env bash
set -euo pipefail

# scripts/generate_secrets.sh
# Helper to produce single-line base64 for .p12 and .mobileprovision files,
# optionally copy to clipboard or upload to GitHub Secrets via gh CLI.

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --p12 FILE                 Path to .p12 certificate to encode
  --p12-pass PASSWORD        Password for the .p12 (optional; will prompt if needed for export/verification)
  --profile FILE             Path to provisioning profile to encode (optional)
  --out-dir DIR              Directory to write generated base64 files (default: ./secrets-out)
  --copy                     Copy generated base64 to clipboard (macOS pbcopy)
  --upload REPO              Upload secrets to GitHub repo using gh (format: owner/repo or omit for current repo)
  --gh-prefix PREFIX         Prefix for secret names (default: APP)
  --help                     Show this help

Examples:
  # generate single-line base64 files
  $0 --p12 signcert.p12 --profile profile.mobileprovision --out-dir ./out

  # copy p12 base64 to clipboard
  $0 --p12 signcert.p12 --copy

  # generate and upload to repo using gh (must be authenticated)
  $0 --p12 signcert.p12 --p12-pass "p12passwd" --upload owner/repo

Notes:
  - The script produces single-line base64 (no newlines) suitable for pasting into GitHub Secrets.
  - If you plan to upload secrets, ensure gh CLI is authenticated and you have repo access.
  - Do NOT commit secrets to git. The script writes files to --out-dir by default; remove them after uploading.
EOF
}

# Defaults
OUT_DIR="./secrets-out"
COPY_TO_CLIPBOARD=0
UPLOAD_REPO=""
GH_PREFIX="APP"
P12_FILE=""
P12_PASS=""
PROFILE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --p12) P12_FILE="$2"; shift 2;;
    --p12-pass) P12_PASS="$2"; shift 2;;
    --profile) PROFILE_FILE="$2"; shift 2;;
    --out-dir) OUT_DIR="$2"; shift 2;;
    --copy) COPY_TO_CLIPBOARD=1; shift 1;;
    --upload) UPLOAD_REPO="$2"; shift 2;;
    --gh-prefix) GH_PREFIX="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
done

mkdir -p "$OUT_DIR"

generate_base64() {
  local infile="$1"; shift
  if [[ ! -f "$infile" ]]; then
    echo "Error: file not found: $infile" >&2
    return 1
  fi
  # Use python3 for portable single-line base64 encoding
  python3 - <<PY
import base64
print(base64.b64encode(open('$infile','rb').read()).decode())
PY
}

save_and_maybe_copy() {
  local name="$1"; local b64="$2"; local outfile="$3"
  printf "%s" "$b64" > "$outfile"
  chmod 600 "$outfile"
  echo "Wrote: $outfile"
  if [[ $COPY_TO_CLIPBOARD -eq 1 ]]; then
    if command -v pbcopy >/dev/null 2>&1; then
      printf "%s" "$b64" | pbcopy
      echo "Copied $name base64 to clipboard"
    else
      echo "Warning: pbcopy not available; cannot copy to clipboard" >&2
    fi
  fi
}

upload_secret() {
  local secret_name="$1"; local infile="$2"; local repo="$3"
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found; cannot upload secrets" >&2
    return 1
  fi
  if [[ -n "$repo" ]]; then
    gh secret set "$secret_name" --repo "$repo" --body "$(cat "$infile")"
  else
    gh secret set "$secret_name" --body "$(cat "$infile")"
  fi
  echo "Uploaded secret: $secret_name ${repo:+to $repo}"
}

# Process .p12
if [[ -n "$P12_FILE" ]]; then
  echo "Processing p12: $P12_FILE"
  P12_B64=$(generate_base64 "$P12_FILE")
  P12_OUT="$OUT_DIR/${GH_PREFIX}_CERT_P12_BASE64.txt"
  save_and_maybe_copy "p12" "$P12_B64" "$P12_OUT"
  if [[ -n "$UPLOAD_REPO" ]]; then
    upload_secret "${GH_PREFIX}_CERT_P12_BASE64" "$P12_OUT" "$UPLOAD_REPO"
  fi
  # Also set p12 password secret if provided
  if [[ -n "$P12_PASS" ]]; then
    if [[ -n "$UPLOAD_REPO" ]]; then
      if command -v gh >/dev/null 2>&1; then
        if [[ -n "$UPLOAD_REPO" ]]; then
          gh secret set "${GH_PREFIX}_CERT_P12_PASSWORD" --repo "$UPLOAD_REPO" --body "$P12_PASS"
        else
          gh secret set "${GH_PREFIX}_CERT_P12_PASSWORD" --body "$P12_PASS"
        fi
        echo "Uploaded secret: ${GH_PREFIX}_CERT_P12_PASSWORD"
      else
        echo "gh CLI not found; cannot upload p12 password" >&2
      fi
    else
      echo "Pass provided; remember to set secret ${GH_PREFIX}_CERT_P12_PASSWORD in GitHub"
    fi
  else
    echo "No p12 password provided. If your p12 needs a password, supply it with --p12-pass or set secret ${GH_PREFIX}_CERT_P12_PASSWORD manually."
  fi
fi

# Process provisioning profile
if [[ -n "$PROFILE_FILE" ]]; then
  echo "Processing provisioning profile: $PROFILE_FILE"
  PROFILE_B64=$(generate_base64 "$PROFILE_FILE")
  PROFILE_OUT="$OUT_DIR/${GH_PREFIX}_PROV_PROFILE_BASE64.txt"
  save_and_maybe_copy "provisioning profile" "$PROFILE_B64" "$PROFILE_OUT"
  if [[ -n "$UPLOAD_REPO" ]]; then
    upload_secret "${GH_PREFIX}_PROV_PROFILE_BASE64" "$PROFILE_OUT" "$UPLOAD_REPO"
  fi
fi

# Final guidance
cat <<EOF
Done. Files written to: $OUT_DIR
If you uploaded secrets with --upload, verify them in the GitHub repository settings.
Remember to remove the generated files when done if they contain secrets.
Example cleanup:
  rm -f $OUT_DIR/*
EOF

exit 0
