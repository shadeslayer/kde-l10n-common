#!/bin/bash

bzr cat lp:~kubuntu-packagers/kubuntu-packaging/kde-l10n-common/debian/common &> debian/common

if ! source debian/common ; then
    echo "could not source common functions!!"
    exit 1
fi

commonSequence

for tfile in `ls kde-l10n-*.tar.xz`; do
    runMapSequence
    bzr branch $CO-langpack language-pack-kde-$ubuntudep

    cd language-pack-kde-$ubuntudep/debian/
    for dfile in `ls`; do
      runSedSequence
      sed -i "s/aaaINPUTMETHODPACKAGEbbb/$inputmethodpkg/g" $dfile
      runBoilerplateSequence
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
    cd ../..
done
