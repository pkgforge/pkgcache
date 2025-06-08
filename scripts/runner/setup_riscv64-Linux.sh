#!/usr/bin/env bash

# VERSION=0.0.1
#-------------------------------------------------------#
## <DO NOT RUN STANDALONE, meant for CI Only>
## Meant to Setup Build Machine
## Self: https://raw.githubusercontent.com/pkgforge/pkgcache/refs/heads/main/scripts/runner/setup_riscv64-Linux.sh
# bash <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/pkgcache/refs/heads/main/scripts/runner/setup_$(uname -m)-$(uname -s).sh")
###-----------------------------------------------------###
### Setups Essential Tools & Preps Sys Environ for Deps ###
### This Script must be run as `root` (passwordless)    ###
### Assumptions: Arch: riscv64 | OS: Debian 64bit       ###
###-----------------------------------------------------###

#-------------------------------------------------------#
##ENV
if [ -z "${SYSTMP+x}" ] || [ -z "${SYSTMP##*[[:space:]]}" ]; then
 SYSTMP="$(dirname $(mktemp -u))" && export SYSTMP="${SYSTMP}"
fi
USER="$(whoami)" && export USER="${USER}"
HOME="$(getent passwd ${USER} | cut -d: -f6)" && export HOME="${HOME}"
if command -v awk &>/dev/null && command -v sed &>/dev/null; then
 PATH="$(echo "${PATH}" | awk 'BEGIN{RS=":";ORS=":"}{gsub(/\n/,"");if(!a[$0]++)print}' | sed 's/:*$//')" ; export PATH
fi
#-------------------------------------------------------#
##Sanity Checks
##Check if it was recently initialized
 # +360  --> 06 Hrs
 # +720  --> 12 HRs
 # +1440 --> 24 HRs
find "${SYSTMP}/INITIALIZED" -type f -mmin +720 -exec rm -rvf "{}" \; 2>/dev/null
if [ -s "${SYSTMP}/INITIALIZED" ]; then
    echo -e "\n[+] Recently Initialized... (Skipping!)\n"
    export CONTINUE="YES"
    return 0 || exit 0
else
 ##Sane Configs
 #In case of removed/privated GH repos
  # https://git-scm.com/docs/git#Documentation/git.txt-codeGITTERMINALPROMPTcode
  export GIT_TERMINAL_PROMPT="0"
  #https://git-scm.com/docs/git#Documentation/git.txt-codeGITASKPASScode
  export GIT_ASKPASS="/bin/echo"
 #Eget
 EGET_TIMEOUT="timeout -k 1m 2m" && export EGET_TIMEOUT="${EGET_TIMEOUT}"
 ##Check for apt
  if ! command -v apt &> /dev/null; then
     echo -e "\n[-] apt NOT Found"
     echo -e "\n[+] Maybe not on Debian (Debian Based Distro) ?\n"
     #Fail & exit
     export CONTINUE="NO"
     return 1 || exit 1
  else
    #Export as noninteractive
    export DEBIAN_FRONTEND="noninteractive"
    export CONTINUE="YES"
  fi
 ##Check for sudo
  if [ "${CONTINUE}" == "YES" ]; then
   if ! command -v sudo &> /dev/null; then
    echo -e "\n[-] sudo NOT Installed"
    echo -e "\n[+] Trying to Install\n"
    #Try to install
     apt-get update -y 2>/dev/null ; apt-get dist-upgrade -y 2>/dev/null ; apt-get upgrade -y 2>/dev/null
     apt install sudo -y 2>/dev/null
    #Fail if it didn't work
     if ! command -v sudo &> /dev/null; then
       echo -e "[-] Failed to Install sudo (Maybe NOT root || NOT enough perms)\n"
       #exit
       export CONTINUE="NO"
       return 1 || exit 1
     fi
   fi
  fi 
 ##Check for passwordless sudo
  if [ "${CONTINUE}" == "YES" ]; then
   if sudo -n true 2>/dev/null; then
       echo -e "\n[+] Passwordless sudo is Configured"
       sudo grep -E '^\s*[^#]*\s+ALL\s*=\s*\(\s*ALL\s*\)\s+NOPASSWD:' "/etc/sudoers" 2>/dev/null
   else
       echo -e "\n[-] Passwordless sudo is NOT Configured"
       echo -e "\n[-] READ: https://web.archive.org/web/20230614212916/https://linuxhint.com/setup-sudo-no-password-linux/\n"
       #exit
       export CONTINUE="NO"
       return 1 || exit 1
   fi
  fi
 ##Install Needed CMDs
  bash <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/devscripts/main/Linux/install_bins_curl.sh")
  sudo curl -qfsSL "https://github.com/pkgforge/bin/releases/download/riscv64-Linux/trufflehog" -o "/usr/local/bin/trufflehog"
  sudo chmod +x "/usr/local/bin/trufflehog"
 ##Check Needed CMDs
 for DEP_CMD in eget gh glab minisign oras rclone shellcheck soar zstd; do
    case "$(command -v "${DEP_CMD}" 2>/dev/null)" in
        "") echo -e "\n[✗] FATAL: ${DEP_CMD} is NOT INSTALLED\n"
           export CONTINUE="NO"
            return 1 || exit 1 ;;
    esac
 done
 ##Check for GITHUB_TOKEN
  if [ -n "${GITHUB_TOKEN+x}" ] && [ -n "${GITHUB_TOKEN##*[[:space:]]}" ]; then
   echo -e "\n[+] GITHUB_TOKEN is Exported"
   ##gh-cli (uses ${GITHUB_TOKEN} env var)
    #echo "${GITHUB_TOKEN}" | gh auth login --with-token
    gh auth status
   ##eget
    #5000 req/minute (80 req/minute)
    eget --rate
  else
   #60 req/hr
    echo -e "\n[-] GITHUB_TOKEN is NOT Exported"
    echo -e "Export it to avoid ratelimits\n"
    eget --rate
   export CONTINUE="NO"
   return 1 || exit 1
  fi
 ##Check for GHCR_TOKEN
  if [ -n "${GHCR_TOKEN+x}" ] && [ -n "${GHCR_TOKEN##*[[:space:]]}" ]; then
   echo -e "\n[+] GHCR_TOKEN is Exported"
   #echo "${GHCR_TOKEN}" | oras login --username "Azathothas" --password-stdin "ghcr.io"
    oras login --username "Azathothas" --password "${GHCR_TOKEN}" "ghcr.io"
  else
    echo -e "\n[-] GHCR_TOKEN is NOT Exported"
    echo -e "Export it to avoid ghcr\n"
   export CONTINUE="NO"
   return 1 || exit 1
  fi
 ##Check for Gitlab Token
  if [ -n "${GITLAB_TOKEN+x}" ] && [ -n "${GITLAB_TOKEN##*[[:space:]]}" ]; then
   echo -e "\n[+] GITLAB is Exported"
    glab auth status
  else
    echo -e "\n[-] GITLAB_TOKEN is NOT Exported"
    echo -e "Export it to avoid ratelimits\n"
   export CONTINUE="NO"
   return 1 || exit 1
  fi
 ##Check for Minisign
  if [[ ! -s "${HOME}/.minisign/pkgforge.key" || $(stat -c%s "${HOME}/.minisign/pkgforge.key") -le 10 ]]; then
    if [ -n "${MINISIGN_KEY+x}" ] && [ -n "${MINISIGN_KEY##*[[:space:]]}" ]; then
      mkdir -pv "${HOME}/.minisign" && \
      echo 'pkgforge-minisign: minisign encrypted secret key' > "${HOME}/.minisign/pkgforge.key" &&\
      echo "${MINISIGN_KEY}" >> "${HOME}/.minisign/pkgforge.key"
     #https://github.com/pkgforge/.github/blob/main/keys/minisign.pub
      export MINISIGN_PUB_KEY='RWSWp/oBUfND5B2fSmDlYaBXPimGV+r2s9skVRYTQ5cJ+7i6ff/1Nxcr'
    else
      echo -e "\n[-] MINISIGN_KEY is NOT Exported"
      echo -e "Export it to Use minisign (Signing)\n"
     export CONTINUE="NO"
     return 1 || exit 1
    fi
  else
   export MINISIGN_PUB_KEY='RWSWp/oBUfND5B2fSmDlYaBXPimGV+r2s9skVRYTQ5cJ+7i6ff/1Nxcr'
  fi
fi
#-------------------------------------------------------#


#-------------------------------------------------------#
##Main
pushd "$(mktemp -d)" &>/dev/null
 echo -e "\n\n [+] Started Initializing $(uname -mnrs) :: at $(TZ='UTC' date +'%A, %Y-%m-%d (%I:%M:%S %p)')\n\n"
 echo -e "[+] USER = ${USER}"
 echo -e "[+] HOME = ${HOME}"
 echo -e "[+] PATH = ${PATH}\n"
#----------------------#
 #Docker
  if [[ "${INSIDE_PODMAN}" != "TRUE" ]]; then
   #Doesn't work inside podman
    if ! command -v docker &> /dev/null; then
     sudo apt install "docker.io" -y
    else
     docker --version
    fi
    #Test
    if ! command -v docker &> /dev/null; then
       echo -e "\n[-] docker NOT Found\n"
       export CONTINUE="NO"
       return 1 || exit 1
    else
      sudo systemctl status "docker.service" --no-pager
      if ! sudo systemctl is-active --quiet docker; then
       sudo service docker restart &>/dev/null ; sleep 10
      fi
      sudo systemctl status "docker.service" --no-pager
    fi
    if ! command -v podman &> /dev/null; then
      sudo apt install podman -y
    fi
    sudo apt install aardvark-dns iproute2 jq iptables netavark -y
    sudo mkdir -p "/etc/containers"
    echo "[engine]" | sudo tee -a "/etc/containers/containers.conf"
    echo "lock_type = \"file\"" | sudo tee -a "/etc/containers/containers.conf"
  fi
 #----------------------# 
 ##Nix
  [[ -f "${HOME}/.bash_profile" ]] && source "${HOME}/.bash_profile"
  [[ -f "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]] && source "${HOME}/.nix-profile/etc/profile.d/nix.sh"
  hash -r &>/dev/null
  if ! command -v nix >/dev/null 2>&1; then
    pushd "$(mktemp -d)" &>/dev/null
     curl -qfsSL "https://raw.githubusercontent.com/pkgforge/devscripts/refs/heads/main/Linux/install_nix.sh" -o "./install_nix.sh"
     dos2unix --quiet "./install_nix.sh" ; chmod +x "./install_nix.sh"
     bash "./install_nix.sh"
     [[ -f "${HOME}/.bash_profile" ]] && source "${HOME}/.bash_profile"
     [[ -f "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]] && source "${HOME}/.nix-profile/etc/profile.d/nix.sh"
    rm -rf "./install_nix.sh" 2>/dev/null ; popd &>/dev/null
  fi
  #Test
   if ! command -v nix &> /dev/null; then
      echo -e "\n[-] nix NOT Found\n"
      export CONTINUE="NO"
      return 1 || exit 1
   else
     #Add Env vars
      export NIXPKGS_ALLOW_BROKEN="1"
      export NIXPKGS_ALLOW_INSECURE="1"
      export NIXPKGS_ALLOW_UNFREE="1"
      export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM="1"  
     #Add Tokens
      echo "access-tokens = github.com=${GITHUB_TOKEN}" | sudo tee -a "/etc/nix/nix.conf" >/dev/null 2>&1
     #Update Channels
      nix --version && nix-channel --list && nix-channel --update
     #Seed Local Data
      nix derivation show "nixpkgs#hello" --impure --refresh --quiet >/dev/null 2>&1
   fi
##Clean
 if [ "${CONTINUE}" == "YES" ]; then
   echo "INITIALIZED" > "${SYSTMP}/INITIALIZED"
   rm -rf "${SYSTMP}/init_Debian" 2>/dev/null
   #-------------------------------------------------------#
   ##END
   echo -e "\n\n [+] Finished Initializing $(uname -mnrs) :: at $(TZ='UTC' date +'%A, %Y-%m-%d (%I:%M:%S %p)')\n\n"
   #In case of polluted env 
   unset AR AS CC CFLAGS CPP CXX CPPFLAGS CXXFLAGS DLLTOOL HOST_CC HOST_CXX LD LDFLAGS LIBS NM OBJCOPY OBJDUMP RANLIB READELF SIZE STRINGS STRIP SYSROOT
 fi
rm -rf "$(realpath .)" && popd &>/dev/null
echo -e "\n[+] Continue : ${CONTINUE}\n"
#-------------------------------------------------------#