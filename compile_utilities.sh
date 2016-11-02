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

# Compile Java* Fuzzer for Android* utilities

function die() {
    echo @*
    exit 1
}

JAVAC="${JAVA_HOME}/bin/javac"
DX="$ANDROID_SDK_ROOT/platform-tools/dx"

cd rb || die "No ./rb directory"
javac *.java || die "Couldn't compile Test.java and FuzzerUtils.java"
dx --dex --output=../classes.dex Test.class || die "Couldn't run dx tool"
rm -f Test.class
cd ..
