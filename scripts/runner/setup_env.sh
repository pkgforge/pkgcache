#!/usr/bin/env bash
##
# source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/pkgcache/refs/heads/main/scripts/runner/setup_env.sh")
##

#-------------------------------------------------------#
unset BUILD_DIR BUILDSCRIPT CONTINUE CONTINUE_SBUILD END_TIME ghcr_push GHCRPKG GHCRPKG_URL GHCRPKG_TAG INPUT_SBUILD INPUT_SBUILD_PATH INITSCRIPT KEEP_LOGS OCWD pkg PKG PKG_FAMILY pkg_id PKG_ID pkg_type PKG_TYPE PROG PUSH_SUCCESSFUL RECIPE SBUILD_OUTDIR SBUILD_PKG SBUILD_PKGS SBUILD_PKGVER SBUILD_REBUILD SBUILD_SCRIPT SBUILD_SCRIPT_BLOB SBUILD_SUCCESSFUL SBUILD_TMPDIR START_TIME TMPDIRS TMPJSON TMPXVER TMPXRUN TOTAL_RECIPES
USER="$(whoami)" && export USER="${USER}"
HOME="$(getent passwd ${USER} | cut -d: -f6)" && export HOME="${HOME}"
if [ -z "${SYSTMP+x}" ] || [ -z "${SYSTMP##*[[:space:]]}" ]; then
 SYSTMP="$(dirname $(mktemp -u))" && export SYSTMP="${SYSTMP}"
fi
export PATH="${HOME}/bin:${HOME}/.cargo/bin:${HOME}/.cargo/env:${HOME}/.go/bin:${HOME}/go/bin:${HOME}/.local/bin:${HOME}/miniconda3/bin:${HOME}/miniconda3/condabin:/usr/local/zig:/usr/local/zig/lib:/usr/local/zig/lib/include:/usr/local/musl/bin:/usr/local/musl/lib:/usr/local/musl/include:${PATH}"
PATH="$(echo "${PATH}" | awk 'BEGIN{RS=":";ORS=":"}{gsub(/\n/,"");if(!a[$0]++)print}' | sed 's/:*$//')" ; export PATH
OWD_TMP="$(realpath .)" ; export OWD_TMP
PKG_REPO="pkgcache"
TMPDIRS="mktemp -d --tmpdir=${SYSTMP}/pkgforge XXXXXXX_SBUILD"
USER_AGENT="$(curl -qfsSL 'https://pub.ajam.dev/repos/Azathothas/Wordlists/Misc/User-Agents/ua_chrome_macos_latest.txt')"
export HOST_TRIPLET PKG_REPO SYSTMP TMPDIRS USER_AGENT
if [[ "${KEEP_PREVIOUS}" != "YES" ]]; then
 rm -rf "${SYSTMP}/pkgforge"
fi
mkdir -pv "${SYSTMP}/pkgforge"
export DEBIAN_FRONTEND="noninteractive"
export GIT_TERMINAL_PROMPT="0"
export GIT_ASKPASS="/bin/echo"
export NIXPKGS_ALLOW_BROKEN="1" 
export NIXPKGS_ALLOW_UNFREE="1"
export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM="1"
EGET_TIMEOUT="timeout -k 1m 2m" && export EGET_TIMEOUT="${EGET_TIMEOUT}"
sudo groupadd docker 2>/dev/null ; sudo usermod -aG docker "${USER}" 2>/dev/null
if ! sudo systemctl is-active --quiet docker; then
 sudo service docker restart >/dev/null 2>&1 ; sleep 10
fi
sudo systemctl status "docker.service" --no-pager
#Nix
source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
#sg docker newgrp "$(id -gn)"
cd "${OWD_TMP}" && unset OWD_TMP && clear
##Sanity Checks
for DEP_CMD in eget gh glab minisign oras rclone soar; do
 case "$(command -v "${DEP_CMD}" 2>/dev/null)" in
     "") echo -e "\n[✗] FATAL: ${DEP_CMD} is NOT INSTALLED\n"
 esac
done
if [[ ! -n "${GITHUB_TOKEN}" ]]; then
 echo -e "\n[-] GITHUB_TOKEN is NOT Exported"
 echo -e "Export it to Use gh (Github)\n"
else
 gh auth status
fi
if [[ ! -n "${GHCR_TOKEN}" ]]; then
 echo -e "\n[-] GHCR_TOKEN is NOT Exported"
 echo -e "Export it to avoid ghcr (Github Registry)\n"
else
 echo "${GHCR_TOKEN}" | oras login --username "Azathothas" --password-stdin "ghcr.io"
fi
if [[ ! -n "${GITLAB_TOKEN}" ]]; then
 echo -e "\n[-] GITLAB_TOKEN is NOT Exported"
 echo -e "Export it to Use glab (Gitlab)\n"
else
 glab auth status
fi
if [[ ! -n "${MINISIGN_KEY}" ]]; then
 echo -e "\n[-] MINISIGN_KEY is NOT Exported"
 echo -e "Export it to Use minisign (Signing)\n"
else
 mkdir -p "${HOME}/.minisign" && \
 echo "pkgforge-minisign: minisign encrypted secret key" > "${HOME}/.minisign/pkgforge.key" &&\
 echo "${MINISIGN_KEY}" >> "${HOME}/.minisign/pkgforge.key"
 #https://github.com/pkgforge/.github/blob/main/keys/minisign.pub
 export MINISIGN_PUB_KEY='RWSWp/oBUfND5B2fSmDlYaBXPimGV+r2s9skVRYTQ5cJ+7i6ff/1Nxcr'
fi
#-------------------------------------------------------#
unset DOCKER_HOST
find "${SYSTMP}" -mindepth 1 \( -type f -o -type d \) -empty -not -path "$(pwd)" -not -path "$(pwd)/*" -delete 2>/dev/null
history -c 2>/dev/null ; rm -rf "${HOME}/.bash_history" ; pushd "$(mktemp -d)" >/dev/null 2>&1 && echo ".keep" > "./.keep"
source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/pkgcache/refs/heads/main/scripts/runner/builder.sh")
alias refresh-buildenv='unset BUILD_DIR BUILDSCRIPT CONTINUE CONTINUE_SBUILD END_TIME ghcr_push GHCRPKG GHCRPKG_URL GHCRPKG_TAG INPUT_SBUILD INPUT_SBUILD_PATH INITSCRIPT KEEP_LOGS OCWD pkg PKG PKG_FAMILY pkg_id PKG_ID pkg_type PKG_TYPE PROG PUSH_SUCCESSFUL RECIPE SBUILD_OUTDIR SBUILD_PKG SBUILD_PKGS SBUILD_PKGVER SBUILD_REBUILD SBUILD_SCRIPT SBUILD_SCRIPT_BLOB SBUILD_SUCCESSFUL SBUILD_TMPDIR START_TIME TMPDIRS TMPJSON TMPXVER TMPXRUN TOTAL_RECIPES ; source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/pkgcache/refs/heads/main/scripts/runner/builder.sh")'
echo -e "\n[+] Build everything: sbuild-builder"
echo -e "[+] ReBuild everything: FORCE_REBUILD_ALL=\"YES\" sbuild-builder"
echo -e "[+] Build local SBUILD: sbuild-builder /path/to/sbuild"
echo -e "[+] ENV (Local): PKG_FAMILY_LOCAL=\"\$PKG_FAMILY\""
echo -e "[+] ENV (Local): GHCRPKG_LOCAL=\"ghcr.io/pkgforge/\$REPO/\$PKG_FAMILY/\$PKG_ID\""
echo -e "[+] Example: SBUILD_REBUILD=\"true\" PKG_FAMILY_LOCAL=\"curl\" GHCRPKG_LOCAL=\"ghcr.io/pkgforge/pkgcache/curl/stunnel\" sbuild-builder \"./curl.SBUILD\""
echo -e "[+] To Preserve Logs: KEEP_LOGS=\"YES\""
echo -e "[+] To Refresh Build Env: refresh-buildenv\n"
#-------------------------------------------------------#