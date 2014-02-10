#!/bin/bash

if ! source debian/common ; then
    echo "could not source common files!!"
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

    bzr branch $CO kde-l10n-$kdecode

    cd kde-l10n-$kdecode/debian/
    for dfile in `ls`; do
      sed -i "s/aaaUBUNTULANGDEPbbb/$ubuntudep/g" $dfile
      sed -i "s/aaaUBUNTULANGCODEbbb/$ubuntucode/g" $dfile
      sed -i "s/aaaKDELANGCODEbbb/$kdecode/g" $dfile
      sed -i "s/aaaKDELANGNAMEbbb/$kdename/g" $dfile
      if [ -z "$inputmethodpkg" ]; then
	sed -i "/aaaINPUTMETHODPACKAGEbbb/d" $dfile
      else
	sed -i "s/aaaINPUTMETHODPACKAGEbbb/$inputmethodpkg/g" $dfile
      fi
      sed -i "s/###BOILERPLATE###/$BOILERPLATE/g" $dfile
    done

    bzr-buildpackage -S --builder "dpkg-buildpackage -S -us -uc"
    cd ../..
  fi
done
