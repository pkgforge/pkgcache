#!/usr/bin/env bash
## <DO NOT RUN STANDALONE, meant for CI Only>
## Self: https://raw.githubusercontent.com/pkgforge/pkgcache/refs/heads/main/scripts/github/sync_releases_metadata.sh
# bash <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/pkgcache/refs/heads/main/scripts/github/sync_releases_metadata.sh")
#-------------------------------------------------------#

#-------------------------------------------------------#
##Sanity
if ! command -v gh &> /dev/null; then
  echo -e "[-] Failed to find Github CLI (gh)\n"
 exit 1 
fi
if [ -z "${GITHUB_TOKEN+x}" ] || [ -z "${GITHUB_TOKEN##*[[:space:]]}" ]; then
  echo -e "\n[-] FATAL: Failed to Find GITHUB_TOKEN (\${GITHUB_TOKEN}\n"
 exit 1
else
  ##gh-cli (uses ${GITHUB_TOKEN} env var)
   #echo "${GITHUB_TOKEN}" | gh auth login --with-token
   gh auth status
fi
##ENV
export TZ="UTC"
SYSTMP="$(dirname $(mktemp -u))" && export SYSTMP="${SYSTMP}"
TMPDIR="$(mktemp -d)" && export TMPDIR="${TMPDIR}" ; echo -e "\n[+] Using TEMP: ${TMPDIR}\n"
if [[ -z "${USER_AGENT}" ]]; then
 USER_AGENT="$(curl -qfsSL 'https://raw.githubusercontent.com/pkgforge/devscripts/refs/heads/main/Misc/User-Agents/ua_chrome_macos_latest.txt')"
fi
##Host
HOST_TRIPLET="$(uname -m)-$(uname -s)"
HOST_TRIPLET_L="${HOST_TRIPLET,,}"
export HOST_TRIPLET HOST_TRIPLET_L
#-------------------------------------------------------#

#-------------------------------------------------------#
##Metadata
pushd "${TMPDIR}" >/dev/null 2>&1
curl -qfsSL "https://meta.pkgforge.dev/pkgcache/${HOST_TRIPLET}.json" -o "${TMPDIR}/${HOST_TRIPLET}.json"
if [[ "$(jq -r '.[] | .ghcr_pkg' "${TMPDIR}/${HOST_TRIPLET}.json" | wc -l)" -le 20 ]]; then
  echo -e "\n[-] FATAL: Failed to Fetch pkgcache (${HOST_TRIPLET}) Metadata\n"
 exit 1
else
  sed -E "s|https://api\.ghcr\.pkgforge\.dev/pkgforge/pkgcache/(.*)\?tag=(.*)\&download=(.*)$|https://github.com/pkgforge/pkgcache/releases/download/\1/\2/\3|g" -i "${TMPDIR}/${HOST_TRIPLET}.json"
  if [[ "$(jq -r '.[] | .ghcr_pkg' "${TMPDIR}/${HOST_TRIPLET}.json" | wc -l)" -gt 20 ]]; then
    #Funcs
    generate_checksum() 
    {
      b3sum "$1" | grep -oE '^[a-f0-9]{64}' | tr -d '[:space:]' > "$1.bsum"
    }
    #To Bita
     bita compress --input "${HOST_TRIPLET}.json" --compression "zstd" --compression-level "21" --force-create "${HOST_TRIPLET}.cba"
    #To xz
     xz -9 -T"$(($(nproc) + 1))" --compress --extreme --keep --force --verbose "${HOST_TRIPLET}.json" ; generate_checksum "${HOST_TRIPLET}.json.xz"
    #To Zstd
     zstd --ultra -22 --force "${HOST_TRIPLET}.json" -o "${HOST_TRIPLET}.json.zstd" ; generate_checksum "${HOST_TRIPLET}.json.zstd"
    #Create & Upload
     gh release create "metadata" --repo "https://github.com/pkgforge/pkgcache" --title "metadata" --prerelease 2>/dev/null
     find "${TMPDIR}" -maxdepth 1 -type f -iname "*${HOST_TRIPLET}*" -size +3c -print0 | xargs -0 -P "$(($(nproc)+1))" -I '{}' gh release upload "metadata" --repo "https://github.com/pkgforge/pkgcache" '{}' --clobber
  fi
fi
popd >/dev/null 2>&1
#-------------------------------------------------------#