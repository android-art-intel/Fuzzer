#!/bin/bash

#--------------------------------------------------------------------------
#
# Copyright (C) 2015 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#--------------------------------------------------------------------------

# -----------------------------------------------------------------------
#
# Usage: ./install_build_manual.sh <path to build on filer>
#
# For example:
# ./install_build_manual.sh /some/path/to/builds/aosp-stable/WW10
#
# As a result, 4 directories containing corresponding builds will be created in $BUILDS_DIR:
#
# /export/users/qa/builds/aosp-master/WW10/HOST-userdebug
# /export/users/qa/builds/aosp-master/WW10/HOST_64-userdebug
#
# -----------------------------------------------------------------------

BUILDS_DIR=<Directory to local host builds>
CURDIR=`pwd`
DEBUG=""
directory=${1}
directory=`echo ${directory} | sed 's|\/$||g'`
build=${directory##/*/}
tmp=${directory%/*}
branch=${tmp##/*/}
echo "BUILD = $build"
echo "BRANCH = $branch"

for platform in `ls ${directory} | grep aosp_x86`
do
    bit=""
    echo $platform | grep "64" &> /dev/null && bit="_64"
    curdir=$BUILDS_DIR/$branch/$build/HOST$bit-userdebug
    echo "Extracting platform $platform to $curdir"
    if [[ ! -d "$curdir" ]]
    then
        $DEBUG mkdir -p $curdir
        $DEBUG cd $curdir
        $DEBUG tar -xzf ${directory}/${platform}/*host.tgz
        $DEBUG chmod -R 775 ./*
    else
        echo "Directory $curdir exists. Skipping"
    fi
done

$DEBUG cd ${CURDIR}
