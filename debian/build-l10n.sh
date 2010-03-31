#!/bin/bash

function mapKdeCodeToUbuntu {
  case `eval "expr \"\$"$1"\" "` in
    "be@latin" )
      eval "$1=\"belatin\"";;
    "ca@valencia" )
      eval "$1=\"cavalencia\"";;
    "en_GB" )
      eval "$1=\"engb\"";;
    "pt_BR" )
      eval "$1=\"ptbr\"";;
    "sr@ijekavian" )
      eval "$1=\"srijekavian\"";;
    "sr@ijekavianlatin" )
      eval "$1=\"srijekavianlatin\"";;
    "sr@latin" )
      eval "$1=\"srlatin\"";;
    "uz@cyrillic" )
      eval "$1=\"uzcyrillic\"";;
    "zh_CN" )
      eval "$1=\"zhcn\"";;
    "zh_TW" )
      eval "$1=\"zhtw\"";;
  esac
}

GET="scp ftpubuntu@ktown.kde.org:/home/packager/ftpubuntu"

clean_dld=1

for arg in "$@"
do
    case "$arg" in
    -ncd)   clean_dld=0
            ;;
    esac
done

WDIR=`pwd`
case ${WDIR##*/} in
  "debian" )
    cd ..;;
  "build" )
    cd ..;;
  "kubuntu-kde-l10n-common" )
    ;;
esac

# clean build dir
if [ $clean_dld -eq 0 ]; then
  ls build/ | grep -v build-area | xargs rm -rf
  ls build/build-area/ | grep -v ".tar.bz2" | xargs rm -rf
else
  rm -rf build
  mkdir build
fi

cd build
WDIR=`pwd`

BRANCH="lp:~kubuntu-members/kubuntu-dev-tools/kde-l10n-common"
CO="common"
BOILERPLATE="# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !#\n# DO NOT EVEN THINK ABOUT CHANGING THIS FILE DIRECTLY! ! ! !\n# PLEASE USE THE BZR BRANCH AS SEEN IN debian\/control\n# MAKE YOUR CHANGES THERE AND THEN RUN debian\/build-l10n.sh\n# kthxbai :)\n################################################################################\n################################################################################\n################################################################################\n################################################################################"

if [[ `bzr revno` != `bzr revno ${BRANCH}` ]]; then
  echo "YOU MUST PUSH TO THE PARENT BRANCH BEFORE BUILDING THE PACKAGES!!!"
  echo "Leaving you alone in the cold."
  exit 1
fi

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
$GET/stable/${KDEVERSION}/src/kde-l10n/kde-l10n-*.tar.bz2 .

for tfile in `ls kde-l10n-*.tar.bz2`; do
  cd $WDIR
  cd build-area

  if [[ $tfile =~ kde-l10n-(.*)-$KDEVERSION.tar.bz2 ]]; then
    kdecode=${BASH_REMATCH[1]}

    ubuntucode=$kdecode
    mapKdeCodeToUbuntu ubuntucode

    # remove any left overs from previous runs
    rm -r kde-l10n-${ubuntucode}_${VERSION}.orig.tar.bz2

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

    bzr-buildpackage -S --builder "make -f debian/rules get-desktop && dpkg-buildpackage -S -sa"
  fi
done
