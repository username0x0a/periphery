#!/bin/bash
#
# Builds a single-file arm64 release binary of Periphery, signs it with a Developer ID certificate, notarizes it, and
# packages it as .release/periphery-<version>.zip for upload to a GitHub release. The details needed to update a
# Homebrew formula for the release are printed at the end.
#
# The binary loads libIndexStore.dylib, which reads the compiler's index store, from the Xcode or Command Line Tools
# installation at runtime.
#
# Usage:
#   scripts/release-binary.sh [--version <version>] [--skip-notarize]
#
# Notarization authenticates with an Apple ID and an app-specific password (created at account.apple.com, under
# Sign-In and Security). Both are prompted for when not set in the environment. The team ID is taken from the signing
# identity.
#
# Environment:
#   PERIPHERY_CODESIGN_IDENTITY  Signing identity, e.g. "Developer ID Application: Name (TEAMID)". Defaults to the
#                                first Developer ID Application identity in the keychain. With --skip-notarize and no
#                                Developer ID identity available, the binary is ad-hoc signed.
#   PERIPHERY_NOTARY_APPLE_ID    Apple ID used for notarization.
#   PERIPHERY_NOTARY_PASSWORD    App-specific password for the Apple ID.
#   PERIPHERY_NOTARY_PROFILE     Optional notarytool keychain profile, used instead of the Apple ID and password.
#   PERIPHERY_RELEASE_REPO       GitHub repository hosting releases (default: username0x0a/periphery).

set -euo pipefail

cd "$(dirname "$0")/.."

repo="${PERIPHERY_RELEASE_REPO:-username0x0a/periphery}"
version="$(sed -n 's/^let PeripheryVersion = "\(.*\)"$/\1/p' Sources/Frontend/Version.swift)"
notarize=true

while [ $# -gt 0 ]; do
  case "$1" in
    --version) version="$2"; shift 2 ;;
    --skip-notarize) notarize=false; shift ;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

step () {
  printf '\n\033[1;32m==> %s\033[0m\n' "$1"
}

fail () {
  echo "ERROR: $1" >&2
  exit 1
}

[ -n "${version}" ] || fail "Could not determine version from Sources/Frontend/Version.swift."
grep -q "^let PeripheryVersion = \"${version}\"$" Sources/Frontend/Version.swift \
  || fail "Sources/Frontend/Version.swift does not match version ${version}."

identity="${PERIPHERY_CODESIGN_IDENTITY:-}"

if [ -z "${identity}" ]; then
  identity="$(security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application: .*\)"$/\1/p' | head -n 1)"
fi

if [ "${notarize}" = true ]; then
  [[ "${identity}" == "Developer ID Application"* ]] \
    || fail "Notarization requires a 'Developer ID Application' signing identity, set PERIPHERY_CODESIGN_IDENTITY."

  # Collect the notarization credentials up front, rather than prompting after the build.
  if [ -n "${PERIPHERY_NOTARY_PROFILE:-}" ]; then
    notary_auth=(--keychain-profile "${PERIPHERY_NOTARY_PROFILE}")
  else
    team_id="$(echo "${identity}" | sed -n 's/.*(\([A-Z0-9]*\))$/\1/p')"
    [ -n "${team_id}" ] || fail "Could not determine the team ID from signing identity '${identity}'."

    apple_id="${PERIPHERY_NOTARY_APPLE_ID:-}"
    if [ -z "${apple_id}" ]; then
      read -r -p "Apple ID for notarization: " apple_id < /dev/tty
    fi

    password="${PERIPHERY_NOTARY_PASSWORD:-}"
    if [ -z "${password}" ]; then
      read -r -s -p "App-specific password for ${apple_id}: " password < /dev/tty
      echo
    fi

    [ -n "${apple_id}" ] && [ -n "${password}" ] || fail "An Apple ID and app-specific password are required."
    notary_auth=(--apple-id "${apple_id}" --team-id "${team_id}" --password "${password}")
  fi
fi

identity="${identity:--}"
echo "Signing identity: ${identity}"
release_dir=".release"
zip_filename="periphery-${version}.zip"

step "Building Periphery ${version}"
xcodebuild -version

# The native build system is used as release builds with cross-module optimization fail to link with swiftbuild, the
# default build system since Swift 6.4.
swift_build_flags=(
  --product periphery
  --configuration release
  --build-system native
  -Xswiftc -cross-module-optimization
  --disable-sandbox
  --scratch-path .build/release-binary
)

rm -rf "${release_dir}"
mkdir -p "${release_dir}"

swift build "${swift_build_flags[@]}" --arch arm64
executable="$(swift build "${swift_build_flags[@]}" --arch arm64 --show-bin-path 2>/dev/null)/periphery"
[ -f "${executable}" ] || fail "Missing executable at ${executable}."

cp "${executable}" "${release_dir}/periphery"
strip -rSTX "${release_dir}/periphery"

step "Setting runtime search paths"
# Replace the rpaths into the build machine's toolchain and build directories with the standard locations of
# libIndexStore.dylib, in order of preference, followed by the Swift runtime in the OS. A libIndexStore.dylib placed
# next to the binary takes precedence, for Xcode installations in other locations.
rpaths=(
  @loader_path
  /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib
  /Applications/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib
  /Library/Developer/CommandLineTools/usr/lib
  /usr/lib/swift
)

otool -l "${release_dir}/periphery" | awk '/LC_RPATH/ { getline; getline; print $2 }' | sort -u | while read -r rpath; do
  install_name_tool -delete_rpath "${rpath}" "${release_dir}/periphery"
done

for rpath in "${rpaths[@]}"; do
  install_name_tool -add_rpath "${rpath}" "${release_dir}/periphery"
done

step "Testing release binary"
"${release_dir}/periphery" version | grep -qx "${version}" || fail "Release binary reports an unexpected version."
"${release_dir}/periphery" scan --strict --quiet

step "Signing"
if [ "${identity}" = "-" ]; then
  codesign --force --sign - "${release_dir}/periphery"
else
  codesign --force --options runtime --timestamp --sign "${identity}" "${release_dir}/periphery"
fi
codesign --verify --strict --verbose=2 "${release_dir}/periphery"
# The hardened runtime enforces library validation, ensure the signed binary still loads libIndexStore.dylib.
"${release_dir}/periphery" version > /dev/null || fail "Signed release binary failed to launch."

step "Packaging ${zip_filename}"
(cd "${release_dir}" && zip -q -X "${zip_filename}" periphery)

if [ "${notarize}" = true ]; then
  step "Notarizing (this may take a few minutes)"
  submission="$(xcrun notarytool submit "${release_dir}/${zip_filename}" \
    "${notary_auth[@]}" --wait --output-format json)"
  echo "${submission}"
  status="$(echo "${submission}" | /usr/bin/python3 -c 'import json, sys; print(json.load(sys.stdin)["status"])')"

  if [ "${status}" != "Accepted" ]; then
    submission_id="$(echo "${submission}" | /usr/bin/python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])')"
    xcrun notarytool log "${submission_id}" "${notary_auth[@]}" || true
    fail "Notarization finished with status '${status}'."
  fi
else
  step "Skipping notarization"
fi

sha256="$(shasum -a 256 "${release_dir}/${zip_filename}" | awk '{ print $1 }')"

url="https://github.com/${repo}/releases/download/${version}/${zip_filename}"

step "Done"
echo "Archive: ${release_dir}/${zip_filename}"
echo
echo "Upload the archive to the ${version} release, e.g.:"
echo "  gh release create ${version} --repo ${repo} ${release_dir}/${zip_filename}"
echo
echo "Homebrew formula:"
echo "  version \"${version}\""
echo "  url \"${url}\""
echo "  sha256 \"${sha256}\""
