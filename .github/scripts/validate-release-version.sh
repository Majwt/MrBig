#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^(0|[1-9][0-9]{0,4})\.(0|[1-9][0-9]{0,4})\.(0|[1-9][0-9]{0,4})(-rc[1-9][0-9]*)?$ ]]; then
    echo "::error::Version must be X.Y.Z or X.Y.Z-rcN without leading zeros."
    exit 1
fi
base_version="${VERSION%-rc*}"
IFS=. read -r major minor build <<< "$base_version"
for component in "$major" "$minor" "$build"; do
    if (( component > 65535 )); then
        echo "::error::Version components must not exceed 65535."
        exit 1
    fi
done

version_is_newer() {
    local candidate="$1" previous="$2"
    local candidate_base="${candidate%-rc*}" previous_base="${previous%-rc*}"
    if [[ "$candidate_base" != "$previous_base" ]]; then
        [[ $(printf '%s\n' "$candidate_base" "$previous_base" | sort -V | tail -n 1) == "$candidate_base" ]]
    elif [[ "$candidate" != *-rc* ]]; then
        [[ "$previous" == *-rc* ]]
    elif [[ "$previous" == *-rc* && "$candidate" != "$previous" ]]; then
        [[ $(printf '%s\n' "${candidate##*-rc}" "${previous##*-rc}" | sort -n | tail -n 1) == "${candidate##*-rc}" ]]
    else
        return 1
    fi
}

latest_version=""
while IFS= read -r release_tag; do
    release_version="${release_tag#v}"
    if [[ ! "$release_version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-rc[1-9][0-9]*)?$ ]]; then
        continue
    fi
    if [[ -z "$latest_version" ]] || version_is_newer "$release_version" "$latest_version"; then
        latest_version="$release_version"
    fi
done < <(git tag --list)
if [[ -n "$latest_version" ]]; then
    if ! version_is_newer "$VERSION" "$latest_version"; then
        echo "::error::Version $VERSION must be newer than the latest version tag ($latest_version)."
        exit 1
    fi
    echo "Preparing $VERSION after $latest_version."
fi