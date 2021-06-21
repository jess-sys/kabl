#!/usr/bin/env bash

if [[ $1 == 'help' ]] || [ "$#" -eq 0 ]
then
  printf "kabl - Diplomatic cables made easy\n"
  printf "\n";
  printf "kabl install \t\t\t install dependencies (git, git-crypt, glow, gpg)\n"
  printf "kabl settle \t\t\t install kabl to /usr/local/sbin\n"
  printf "\n";
  printf "kabl allow <file_name.gpg> \t import given key file to GPG keyring and adds its id to allowed keys\n"
  printf "kabl allowid <gpg_id> \t\t allow gpg_id to decrypt this repo\n"
  printf "\n";
  printf "kabl init \t\t\t create and encrypt (with configured key) this repository\n"
  printf "kabl create <file_name> \t create and encrypt (with configured key) given file\n"
  printf "kabl read <file_name> \t\t decrypt, read and encrypt (with configured key) given file\n"
  printf "kabl edit <file_name> \t\t decrypt, edit and encrypt (with configured key) given file\n"
  exit
fi

if [[ $1 == 'install' ]]
then
  packagesNeeded='git gnupg2 git-crypt glow'
  echo "Trying to install packages: $packagesNeeded"
  if [ -x "$(command -v apk)" ];       then sudo apk add --no-cache $packagesNeeded
  elif [ -x "$(command -v apt-get)" ]; then sudo apt-get install $packagesNeeded
  elif [ -x "$(command -v dnf)" ];     then sudo dnf install $packagesNeeded
  elif [ -x "$(command -v brew)" ];    then brew install $packagesNeeded
  elif [ -x "$(command -v zypper)" ];  then sudo zypper install $packagesNeeded
  else echo "FAILED TO INSTALL PACKAGE: Package manager not found. You must manually install: $packagesNeeded">&2; fi
  exit
fi

if [[ $1 == 'settle' ]]
then
  sudo cp ./kabl.sh /usr/local/sbin/kabl
  sudo chmod +x /usr/local/sbin/kabl
  exit
fi

if ! command -v gpg -v &> /dev/null
then
  echo "Missing dependency: gpg"
  exit
fi

if ! command -v git -v &> /dev/null
then
  echo "Missing dependency: git"
  exit
fi

if ! command -v git-crypt -v &> /dev/null
then
  echo "Missing dependency: git-crypt"
  exit
fi

if command -v glow -v &> /dev/null
then
  MD_VIEWER=glow
else
  MD_VIEWER=less
fi

init_crypt() {
  git init . &>/dev/null || true
  mkdir documents/
  git-crypt init &> /dev/null
  if [ "$?" -ne 0 ]; then
    echo "Error: failed to create keys"
  fi
  echo "*.key filter=git-crypt diff=git-crypt" > .gitattributes
  echo "documents/** filter=git-crypt diff=git-crypt" >> .gitattributes
  git add .
  git commit -am "Initialize repository : add encryption files" &> /dev/null
  if [ "$?" -ne 0 ]; then
    echo "Error: failed to init repository"
  fi
  echo "Initialized encrypted repository"
}

if [[ $1 == 'init' ]]
then
  init_crypt
  exit
fi

encrypt() {
  git-crypt lock
  sh -c 'chmod -Rf 400 documents/* 2> /dev/null || true'
}

decrypt() {
  git-crypt unlock
  sh -c 'chmod -Rf 600 documents/* 2> /dev/null || true'
}

save() {
  git add documents/*
  git commit -am "Kabl automatic commit" &>/dev/null
  if [ "$?" -ne 0 ]; then
    echo "Error: failed to commit"
  else
    echo "Saved new document revision"
  fi
}

if [ "$#" -ne 2 ]; then
  echo "Error: Missing resource identifier (file name or ID)"
fi

if [[ $1 == 'read' ]]
then
  decrypt;
  $MD_VIEWER $2 2> /dev/null; 
  if [[ "$?" -ne 0 ]]; then
    echo "$2 : no such file or directory"
  fi 
  encrypt
  exit
fi

if [[ $1 == 'edit' ]]
then
  decrypt;
  nano $2; 
  save;
  encrypt;
  exit
fi

if [[ $1 == 'allow' ]]
then
  gpg --import $2
  # list keys and add key to git-crypt
  exit
fi

if [[ $1 == 'allowid' ]]
then
  git-crypt add-gpg-user $2 &> /dev/null
  if [[ "$?" -ne 0 ]]; then
    echo "Error : no key with id $2 found in GPG keyring"
  fi 
  exit
fi

# command : import to gpg keyring from file (and in git-crypt auto)
# command : add GPG ID to git-crypt
# command : generate pdf from file
