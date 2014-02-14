#!/bin/bash

# bzr cat lp:~kubuntu-packagers/kubuntu-packaging/kde-l10n-common/debian/common &> debian/common
# 
if ! source debian/common ; then
    echo "could not source common functions!!"
    exit 1
fi

###################################

checkDependencies
cdMainDirectory "kde-l10n-common"

includeConfig
ensureBranchIsPushed

clean_dld=1
subset=""

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

exportDirectories

# clean build dir
if [ $clean_dld -eq 0 ]; then
    find $BUILD_DIR/* -maxdepth 0 | grep -v build-area | xargs rm -rfv
    find $BUILD_AREA_DIR//* -maxdepth 0 | grep -v ".tar.xz" | xargs rm -rfv
else
    purgeBuildDirectory
fi

# Safe even with a partial clean up.
initBuildDirectory

bzr branch $BRANCH $CO

cd $CO
VERSION=`dpkg-parsechangelog | sed -ne 's/^Version: \(\([0-9]\+\):\)\?\(.*\)-.*/\3/p'`
if [[ ${VERSION} =~ (.*)([abcdefghijklmnopqrstuvwxyz]) ]]; then
    KDEVERSION=${BASH_REMATCH[1]}
else
    KDEVERSION=$VERSION
fi
cd $BUILD_DIR

cd build-area

# only download tars if we actually removed them
if [ $clean_dld -ne 0 ]; then
    if [[ "$subset" == "" ]]; then
        # get all
        $REMOTE_GET_BASE/${TYPE}/${KDEVERSION}/src/kde-l10n/kde-l10n-*.tar.xz .
    else
        # only get subset
        for pkg in $subset; do
            $REMOTE_GET_BASE/${TYPE}/${KDEVERSION}/src/kde-l10n/kde-l10n-$pkg-*.tar.xz .
        done
    fi
fi

for tfile in `ls kde-l10n-*.tar.xz`; do
    cd $BUILD_DIR

    if [[ $tfile =~ kde-l10n-(.*)-$KDEVERSION.tar.xz ]]; then
        exportCodeMappings ${BASH_REMATCH[1]}

        ### TODO inputmethodpkg

        cd $BUILD_AREA_DIR

        # Remove any left overs from previous runs.
        rm -r kde-l10n-${UBUNTUCODE}_${VERSION}.orig.tar.xz

        ln -s $tfile kde-l10n-${UBUNTUCODE}_${VERSION}.orig.tar.xz
        tar xf kde-l10n-${UBUNTUCODE}_${VERSION}.orig.tar.xz

        # Read the spelled out name of the language from the desktop file
        # e.g. 'German' for 'de'. This will be used to substitute Description
        # fields in the debian/control file.
        ### TODO: probably should be a function
        i=0
        while read line; do
            ((i++))
            if [ $i -eq 2 ]; then
                export KDENAME=`echo "$line" | cut -f2 -d=`
                break
            fi
        done < kde-l10n-$KDECODE-$KDEVERSION/messages/entry.desktop
        rm -rf kde-l10n-$KDECODE-$KDEVERSION
    else
        echo "!!! SKIPPING $tar_file BECAUSE THE VERSION COULD NOT BE PARSED!!!"
        continue
    fi

    inputmethodpkg=""
    kdeCodeToIBusPackage inputmethodpkg
    export ADDITIONALDEPS="$inputmethodpkg"

    cd $BUILD_DIR
    bzr branch $CO kde-l10n-$kdecode

    cd kde-l10n-$kdecode/debian/
    for debian_file in `ls`; do
        gsubDebianFile $debian_file
    done

    bzr-buildpackage -S --builder "dpkg-buildpackage -S -us -uc"
    cd ../..
done
