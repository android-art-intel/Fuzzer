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
# Usage: ./install_build.sh <branch> <build name>
#
# For example:
# ./extract_builds.sh aosp-stable WW10
#
# As a result, 4 directories containing corresponding builds will be created in /export/users/host_builds:
#
# /export/users/qa/builds/aosp-master/WW10/HOST-userdebug
# /export/users/qa/builds/aosp-master/WW10/HOST_64-userdebug
#
# -----------------------------------------------------------------------



WEBSHARE_BUILDS_DIR=<Path to stored and archived builds>
export directory="$WEBSHARE_BUILDS_DIR/${1}/${2}"
. ./install_build_manual.sh "${directory}"
exit 0
