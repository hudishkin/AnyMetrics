#!/bin/sh
# Local settings for `tuist generate`.
# cp generate.example.sh generate.sh, uncomment and fill in the values, then run ./generate.sh
# generate.sh is ignored by git. An exported empty value overrides the default in Project.swift,
# so keep unused lines commented out.
set -e

# export TUIST_TEAM_ID="XXXXXXXXXX"
# export TUIST_BUILDER_API_URL="https://api.example.com"
# export TUIST_GITHUB_CLIENT_ID="Ov23..."
# export TUIST_GOOGLE_CLIENT_ID="1234567890-abc.apps.googleusercontent.com"

cd "$(dirname "$0")"
tuist install
tuist generate "$@"
