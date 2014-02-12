#!/bin/bash

bzr cat lp:~kubuntu-packagers/kubuntu-packaging/kde-l10n-common/debian/common &> debian/common

if ! source debian/common ; then
    echo "could not source common functions!!"
    exit 1
fi

commonSequence

for tfile in `ls kde-l10n-*.tar.xz`; do
    runMapSequence
    bzr branch $CO kde-l10n-$kdecode

    cd kde-l10n-$kdecode/debian/
    for dfile in `ls`; do
      runSedSequence
      if [ -z "$inputmethodpkg" ]; then
	sed -i "/aaaINPUTMETHODPACKAGEbbb/d" $dfile
      else
	sed -i "s/aaaINPUTMETHODPACKAGEbbb/$inputmethodpkg/g" $dfile
      fi
      runBoilerplateSequence
    done

    bzr-buildpackage -S --builder "dpkg-buildpackage -S -us -uc"
    cd ../..
done
