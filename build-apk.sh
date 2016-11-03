#!/bin/bash

#--------------------------------------------------------------------------
#
# Copyright (C) 2016 Intel Corporation
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

function log(){
    echo `date +"%Y-%m-%d %H:%M:%S"` $@
}

function die(){
    log "ERROR: $@"
    exit 1
}

JAVA_HOME=${JAVA_HOME:-/usr/bin/java}

filerdir=${1:-.}
PWD_=`pwd`

echo "package com.intel.fuzzer;" > $filerdir/apk/Fuzzer/src/com/intel/fuzzer/FuzzerUtils.java
cat $filerdir/rb/FuzzerUtils.java >> $filerdir/apk/Fuzzer/src/com/intel/fuzzer/FuzzerUtils.java

cd $filerdir/apk/Fuzzer && \
ant clean && \
ant release && \
cp bin/Fuzzer-release-unsigned.apk bin/Fuzzer.apk && \
$JAVA_HOME/bin/jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keypass fuzzer -storepass fuzzer \
-keystore ../keystore/fuzzer.keystore bin/Fuzzer.apk fuzzer_apk && echo "Building and signing Fuzzer apk succeed!" || die "Errors during compiling Fuzzer!"
cp bin/Fuzzer.apk "$PWD_"/
chmod -R 775 bin gen
cd $PWD_
