#!/usr/bin/env bash
#
# Point the Homebrew cask at a published release:
#
#     tool/bump_cask.sh            # the version in pubspec.yaml
#     tool/bump_cask.sh v0.1.6     # a particular one
#
# Why a cask at all: the macOS app is signed ad-hoc rather than with a Developer
# ID, so a disk image that arrives through a browser carries the quarantine
# attribute and Gatekeeper stops it until the reader allows it by hand from
# Settings. Homebrew strips that attribute itself, so `brew install --cask` is
# the one route that just works without notarising — and notarising needs the
# paid certificate.
#
# The cask lives in its own repository because a tap has to be named
# homebrew-<something>. This script lives here, with the rest of the release
# tooling, because bumping it is part of publishing rather than part of the tap.
#
# It runs *after* the release is published, and deliberately downloads the file
# GitHub is serving rather than checksumming a local build: a cask whose sha256
# does not match what the reader downloads refuses to install, and catching that
# is most of what the checksum is for.
#
# The whole cask is generated rather than edited in place. There is one app in
# this tap and one thing that changes about it, so a template with holes in it
# would only be a second place for the version to be wrong.
set -euo pipefail

cd "$(dirname "$0")/.."

for tool in gh git shasum; do
  command -v "$tool" >/dev/null || { echo "missing $tool" >&2; exit 1; }
done

tap=duvanherfi/homebrew-tunebox

if [[ $# -gt 0 ]]; then
  tag=$1
else
  full=$(sed -n 's/^version: *//p' pubspec.yaml | tr -d '[:space:]')
  tag="v${full%%+*}"
fi

# The build number is not in the tag, so it comes from the asset that is
# actually attached to the release rather than from pubspec — which may already
# have moved on to the next version.
asset=$(gh release view "$tag" --json assets --jq '.assets[].name | select(endswith(".dmg"))')
[[ -n "$asset" ]] || {
  echo "$tag has no .dmg attached — nothing to point the cask at" >&2
  exit 1
}
[[ $(wc -l <<<"$asset") -eq 1 ]] || { echo "$tag has more than one .dmg" >&2; exit 1; }

# tunebox-0.1.6+7.dmg -> 0.1.6 and 7
rest=${asset#tunebox-}
rest=${rest%.dmg}
version=${rest%%+*}
build=${rest##*+}
[[ "$version" != "$build" && -n "$version" && -n "$build" ]] || {
  echo "cannot read a version out of '$asset'" >&2
  exit 1
}

url="https://github.com/duvanherfi/tunebox/releases/download/$tag/$asset"

echo "==> checksumming what GitHub serves for $tag"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$url" -o "$tmp/$asset"
sha=$(shasum -a 256 "$tmp/$asset" | cut -d' ' -f1)
echo "    $sha"

echo "==> writing the cask"
git clone -q "git@github.com:$tap.git" "$tmp/tap"
mkdir -p "$tmp/tap/Casks"
cat > "$tmp/tap/Casks/tunebox.rb" <<CASK
cask "tunebox" do
  version "$version,$build"
  sha256 "$sha"

  url "https://github.com/duvanherfi/tunebox/releases/download/v#{version.csv.first}/tunebox-#{version.csv.first}+#{version.csv.second}.dmg"
  name "Tunebox"
  desc "Music player that reads the YouTube Music catalogue through InnerTube"
  homepage "https://github.com/duvanherfi/tunebox"

  # The version carries the build number after a comma because Android is what
  # decides when an install is an upgrade, and it goes by that number alone.
  # Left to itself livecheck would read the tag and answer 0.1.6, which never
  # matches, so it reads the asset name instead — the same place the in-app
  # updater reads it from.
  livecheck do
    url :url
    regex(/tunebox[._-]v?(\d+(?:\.\d+)+)\+(\d+)\.dmg/i)
    strategy :github_latest do |json, regex|
      json["assets"]&.map do |asset|
        match = asset["name"]&.match(regex)
        next if match.blank?

        "#{match[1]},#{match[2]}"
      end
    end
  end

  depends_on macos: :catalina

  app "tunebox.app"

  # The app keeps its library, downloads and play log under its own bundle id,
  # and its session cookies in the keychain, which \`zap\` cannot reach — those
  # have to go by hand from Keychain Access if you want no trace left.
  zap trash: [
    "~/Library/Application Support/com.tunebox.tunebox",
    "~/Library/Caches/com.tunebox.tunebox",
    "~/Library/HTTPStorages/com.tunebox.tunebox",
    "~/Library/Preferences/com.tunebox.tunebox.plist",
    "~/Library/Saved Application State/com.tunebox.tunebox.savedState",
  ]
end
CASK

cd "$tmp/tap"
git add Casks/tunebox.rb
git diff --cached --quiet && { echo "the cask already points at $tag"; exit 0; }
git commit -q -m "tunebox $version+$build"
git push -q origin HEAD
echo "==> $tap now serves $version+$build"
echo
echo "    brew install --cask $tap/tunebox"
