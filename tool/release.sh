#!/usr/bin/env bash
#
# Check what cannot be undone, then hand the release to CI:
#
#     tool/release.sh
#
# The build, the signature and the publishing happen in .github/workflows/
# release.yml, which wakes up when this pushes the tag. What stays here is
# everything that has to be true *before* the tag exists, because a tag that
# has been pushed is the one step of a release that does not come back cleanly.
#
# So this needs no signing key: the laptop stopped signing releases. The key
# lives in the release environment on GitHub, where a workflow reads it only
# after you approve the run.
set -euo pipefail

cd "$(dirname "$0")/.."

for tool in flutter git gh; do
  command -v "$tool" >/dev/null || { echo "missing $tool" >&2; exit 1; }
done

[[ -z "$(git status --porcelain)" ]] || {
  echo "working tree is dirty; commit or stash first" >&2
  exit 1
}

branch=$(git rev-parse --abbrev-ref HEAD)
[[ "$branch" == main ]] || { echo "on $branch, not main" >&2; exit 1; }

# `0.1.4+5` — the version line is the single source for both numbers. The
# workflow reads it again from the tagged commit and stops if the two disagree.
full=$(sed -n 's/^version: *//p' pubspec.yaml | tr -d '[:space:]')
version=${full%%+*}
build=${full##*+}
tag="v$version"
[[ "$version" != "$build" ]] || {
  echo "pubspec version '$full' has no build number" >&2
  exit 1
}

git rev-parse -q --verify "refs/tags/$tag" >/dev/null && {
  echo "$tag already exists; bump version in pubspec.yaml first" >&2
  exit 1
}
gh release view "$tag" >/dev/null 2>&1 && {
  echo "$tag is already published" >&2
  exit 1
}

# The workflow looks the notes up by tag rather than being handed a path, so a
# missing file would only surface after the tag was pushed. Cheaper here.
notes="docs/releases/$tag.md"
[[ -s "$notes" ]] || { echo "write the release notes at $notes first" >&2; exit 1; }

# The commit about to be tagged has already been through CI on its way into
# main. This is here for the case that matters — a tag cut from a working tree
# that only looks like main — and it costs a minute and a half.
echo "==> $tag ($full)"
flutter pub get
flutter analyze
flutter test

echo "==> pushing the tag"
git tag -a "$tag" -m "Tunebox $version"
git push origin "$tag"

remote=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
echo
echo "==> $tag pushed. The rest happens in Actions:"
echo "    https://github.com/$remote/actions/workflows/release.yml"
echo
echo "It waits for your approval before it can read the signing key. Once you"
echo "give it, it builds, signs, checks and publishes tunebox-$full.apk."
echo "If it fails, nothing was published: delete the tag and start again."
