#!/bin/bash


clean_dld=1
subset=""

if [ ! -x /usr/bin/bzr-buildpackage ]; then
  echo "bzr-buildpackage needs to be installed to build kde-l10n packages"
  exit 1
fi

for arg in "$@"
do
    case "$arg" in
    -ncd)
      clean_dld=0
      ;;
    *)
      subset="$subset $arg"
    esac
done

WDIR=`pwd`
case ${WDIR##*/} in
  "debian" )
    cd ..;;
  "build" )
    cd ..;;
  "kde-l10n-common" )
    ;;
esac

if ! source debian/config-l10n ; then
    echo "could not source config!!"
    exit 1
fi

if ! source debian/common ; then
    echo "could not source common functions!!"
    exit 1
fi

if [ -e build ]; then
  echo "A already existing build/ directory was found, which indicates that there was a build done earlier."
  echo "Note: you can also run this script with -ncd to preserve only the tar.xz files from build/."
  echo "Do you REALLY REALLY want to mess with the current build dir? (y/n)"
  read -e reply
  if [[ $reply != "y" ]]; then
    echo "bye!"
    exit 0
  fi
fi

if ! source debian/config-l10n ; then
    echo "could not source config!!"
    exit 1
fi

# clean build dir
if [ $clean_dld -eq 0 ]; then
  find build/* -maxdepth 0 | grep -v build-area | xargs rm -rfv
  find build/build-area/* -maxdepth 0 | grep -v ".tar.xz" | xargs rm -rfv
else
  rm -rvf build
  mkdir build
fi

cd build
WDIR=`pwd`

BOILERPLATE="# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !#\n# DO NOT EVEN THINK ABOUT CHANGING THIS FILE DIRECTLY! ! ! !\n# PLEASE USE THE BZR BRANCH AS SEEN IN debian\/control\n# MAKE YOUR CHANGES THERE AND THEN RUN debian\/build-l10n.sh\n# kthxbai :)\n################################################################################\n################################################################################\n################################################################################\n################################################################################"

if [[ `bzr revno` != `bzr revno ${BRANCH}` ]]; then
  echo "For one reason or another the parent branch does not match the local one, please ensure they match, or all is going down the drain."
  echo "Most importantly: YOU MUST PUSH TO THE PARENT BRANCH BEFORE BUILDING THE PACKAGES!!!"
  echo "Leaving you alone in the cold."
  exit 1
fi

mkdir build-area
bzr branch $BRANCH $CO
bzr branch $LANG_PACK_BRANCH $CO-langpack

cd $CO
VERSION=`dpkg-parsechangelog | sed -ne 's/^Version: \(\([0-9]\+\):\)\?\(.*\)-.*/\3/p'`
if [[ ${VERSION} =~ (.*)([abcdefghijklmnopqrstuvwxyz]) ]]; then
  KDEVERSION=${BASH_REMATCH[1]}
else
  KDEVERSION=$VERSION
fi
cd $WDIR

cd build-area

# only download tars if we actually removed them
if [ $clean_dld -ne 0 ]; then
  if [[ "$subset" == "" ]]; then
    # get all
    $GET/${TYPE}/${KDEVERSION}/src/kde-l10n/kde-l10n-*.tar.xz .
  else
    # only get subset
    for pkg in $subset; do
      $GET/${TYPE}/${KDEVERSION}/src/kde-l10n/kde-l10n-$pkg-*.tar.xz .
    done
  fi
fi


for tfile in `ls kde-l10n-*.tar.xz`; do
  cd $WDIR
  cd build-area

  if [[ $tfile =~ kde-l10n-(.*)-$KDEVERSION.tar.xz ]]; then
    kdecode=${BASH_REMATCH[1]}

    # set mappings
    ubuntucode=$kdecode
    mapKdeCodeToUbuntu ubuntucode

    ubuntudep=$ubuntucode
    mapUbuntuNameToDep ubuntudep
    
    inputmethodpkg=$kdecode
    mapKdeCodeToIbusPkg inputmethodpkg

    # remove any left overs from previous runs
    rm -r kde-l10n-${ubuntucode}_${VERSION}.orig.tar.xz

    ln -s $tfile kde-l10n-${ubuntucode}_${VERSION}.orig.tar.xz
    tar xf kde-l10n-${ubuntucode}_${VERSION}.orig.tar.xz

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

    bzr branch $CO-langpack language-pack-kde-$ubuntudep

    cd language-pack-kde-$ubuntudep/debian/
    for dfile in `ls`; do
      sed -i "s/aaaUBUNTULANGDEPbbb/$ubuntudep/g" $dfile
      sed -i "s/aaaUBUNTULANGCODEbbb/$ubuntucode/g" $dfile
      sed -i "s/aaaKDELANGCODEbbb/$kdecode/g" $dfile
      sed -i "s/aaaKDELANGNAMEbbb/$kdename/g" $dfile
      sed -i "s/aaaINPUTMETHODPACKAGEbbb/$inputmethodpkg/g" $dfile
      sed -i "s/###BOILERPLATE###/$BOILERPLATE/g" $dfile
    done

    CALLIGRA=`apt-cache policy calligra-l10n-${kdecode}`
    if [[ -n $CALLIGRA ]]; then 
        sed -i "s/^Depends:.*/&, calligra-l10n-${kdecode}/" control
    fi

    if [[ $ubuntudep != $kdecode ]]; then
        echo $ubuntudep NOT $kdecode
        sed -i "s/^Depends:.*/&, kde-l10n-${ubuntucode}/" control

        CALLIGRA=`apt-cache policy calligra-l10n-${ubuntucode}`
        if [[ -n $CALLIGRA ]]; then 
           sed -i "s/^Depends:.*/&, calligra-l10n-${ubuntucode}/" control
        fi
    fi

    bzr-buildpackage -S --builder "dpkg-buildpackage -S -us -uc"
  fi
done
