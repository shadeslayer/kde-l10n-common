#!/bin/bash

function mapKdeCodeToUbuntu {
  case `eval "expr \"\$"$1"\" "` in
    "en_GB" )
      eval "$1=\"engb\"";;
    "pt_BR" )
      eval "$1=\"ptbr\"";;
    "sr@latin" )
      eval "$1=\"srlatin\"";;
    "zh_CN" )
      eval "$1=\"zhcn\"";;
    "zh_TW" )
      eval "$1=\"zhtw\"";;
  esac
}

# if [ $1 == "ftp" ]; then
#   GET=
# else
  GET="scp ftpubuntu@ktown.kde.org:/home/packager/ftpubuntu"
# fi

WDIR=`pwd`
case ${WDIR##*/} in
  "debian" )
    cd ..;;
  "kde-l10n-common" )
    ;;
esac
rm -r build
mkdir build
cd build
WDIR=`pwd`

# BRANCH="lp:~kubuntu-members/ubuntu/kde-l10n-common"
BRANCH="/home/me/src/bzr/kde-l10n-common"
CO="common"
BOILERPLATE="# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !#\n# DO NOT EVEN THINK ABOUT CHANGING THIS FILE DIRECTLY! ! ! !\n# PLEASE USE THE BZR BRANCH AS SEEN IN debian\/control\n# MAKE YOUR CHANGES THERE AND THEN RUN debian\/build-l10n.sh\n# kthxbai :)\n################################################################################\n################################################################################\n################################################################################\n################################################################################"

langs=()

mkdir build-area
bzr branch $BRANCH $CO

cd $CO
VERSION=`dpkg-parsechangelog | sed -ne 's/^Version: \(\([0-9]\+\):\)\?\(.*\)-.*/\3/p'`
if [[ ${VERSION} =~ (.*)([abcdefghijklmnopqrstuvwxyz]) ]]; then
  KDEVERSION=${BASH_REMATCH[1]}
else
  KDEVERSION=$VERSION
fi
cd $WDIR

cd build-area
$GET/stable/${KDEVERSION}/src/kde-l10n/kde-l10n-c*.tar.bz2 .

for tfile in `ls kde-l10n-*.tar.bz2`; do
  cd $WDIR
  cd build-area

  if [[ $tfile =~ kde-l10n-(.*)-$KDEVERSION.tar.bz2 ]]; then
    kdecode=${BASH_REMATCH[1]}

    ubuntucode=$kdecode
    mapKdeCodeToUbuntu ubuntucode

    ln -s $tfile kde-l10n-${ubuntucode}_${VERSION}.orig.tar.bz2
    tar xf kde-l10n-${ubuntucode}_${VERSION}.orig.tar.bz2

    i=0
    while read line; do
      ((i++))
      if [ $i -eq 2 ]; then
        kdename=`echo "$line" | cut -f2 -d=`
        break
      fi
    done < kde-l10n-$kdecode-$KDEVERSION/messages/entry.desktop
    rm -rf kde-l10n-$kdecode-$KDEVERSION

##############################
    cd $WDIR

    bzr branch $CO kde-l10n-$kdecode

    cd kde-l10n-$kdecode/debian/
    for dfile in `ls`; do
      sed -i "s/aaaUBUNTULANGCODEbbb/$ubuntucode/g" $dfile
      sed -i "s/aaaKDELANGCODEbbb/$kdecode/g" $dfile
      sed -i "s/aaaKDELANGNAMEbbb/$kdename/g" $dfile
      sed -i "s/###BOILERPLATE###/$BOILERPLATE/g" $dfile
    done

    bzr-buildpackage --builder "make -f debian/rules get-desktop && dpkg-buildpackage -S -sa"
  fi
done

# for tfile in `ls kde-l10n-*.tar.bz2`; do
#   if [[ $tfile =~ kde-l10n-(.*)-$VERSION.tar.bz2 ]]; then
#     langs[${#langs[@]}]=${BASH_REMATCH[1]}
#     mv $tfile kde-l10n-${BASH_REMATCH[1]}_$VERSION.orig.tar.bz2
#     tar xf $tfile
#     cd kde-l10n-$VERSION
# 
# 
#   fi
# done
# index=0
# count=${#langs[@]}
# while [ "$index" -lt "$count" ]; do
#   echo ${langs[$index]}
#   ((index++))
# done



# function buildPkg {
#   cd $WDIR
#
#   kdecode=$1
#   ubuntucode=$2
#   kdename=$3
#
#   bzr branch $CO kde-l10n-$kdecode
#
#   cd kde-l10n-$kdecode/debian/
# #   i=0
# #   while read line; do
# #     ((i++))
# #     if [ i -eq 2 ]; then
# #       kdename=`echo "$line" | cut -f2 -d=`
# #       break
# #     fi
# #   done < messages/entry.desktop
#
# #   kdecode=`grep "set(CURRENT_LANG.*)" CMakeLists.txt`
# #   if [[ $kdecode =~ set\(CURRENT_LANG(.*)\) ]]; then
# #     kdecode=${BASH_REMATCH[1]}
# #     ubuntucode=$kdecode
# #     mapKdeCodeToUbuntu ubuntucode
# #   fi
#
#   for dfile in `ls`; do
#     sed -i "s/aaaUBUNTULANGCODEbbb/$ubuntucode/g" $dfile
#     sed -i "s/aaaKDELANGCODEbbb/$kdecode/g" $dfile
#     sed -i "s/aaaKDELANGNAMEbbb/$kdename/g" $dfile
#   done
#
#   bzr builddeb -S
# }