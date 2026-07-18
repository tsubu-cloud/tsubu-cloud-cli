#!/usr/bin/env bash
set -euo pipefail

latest=$(git tag -l 'v[0-9]*' | sed 's/^v//' | sort -n | tail -1)
next=$(( ${latest:-0} + 1 ))
tag="v${next}"

git tag "$tag" HEAD
git push origin "$tag"
echo "Tagged HEAD as $tag and pushed"
