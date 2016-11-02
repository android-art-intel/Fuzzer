#Java* Fuzzer for Android* 

Java* Fuzzer for Android* is a random Java tests generator intended to run on Android VM (Dalvik, ART). The tool compares the result of execution using JIT/AOT/interpreter modes or Java VM that allows to detect crashes, hangs and incorrect calculations. The main idea of the tool is to generate hundreds of thousands small random tests cover various cases using pre-defined test generator heuristics and provide a strong testing for Java VM compiler and runtime.

## Table of contents
1. [Setup and maintenance](#setup-and-maintenance)
2. [Android host build structure](#android-host-build-structure)
3. [Tool files descrption](#the-tool-files-description)
    1. [Scripts](#scripts)
    2. [Java sources](#java-source-files)
    3. [Ruby sources](#ruby-source-files)
4. [Weekly manual testing](#weekly-manual-testing)
   1. [How to run the tool](#how-to-run-the-tool)
5. [MM extension manual testing](#mm-extension-manual-testing)
6. [Running tests on device](#running-tests-on-device)
7. [Running tests in JIT_PROFILE mode on device](#running-tests-in-jit_profile-mode-on-device)
8. [Authors](#authors)

## Setup and maintenance

Prepare the environment:
- Software:
  - JDK version 7 or higher
  - Ruby version 1.8.7 or higher
  - Android SDK version 22 or higher
  - Apache ANT version 1.8.2 or higher
- Environment variables:
  - ANDROID_SDK_ROOT should point to the Android SDK location
  - JAVA_HOME should point to the JDK location
  - ANT_HOME should point to the apache ant location
- Ensure that **dx** tool from Android SDK is located in 
*$ANDROID_SDK_ROOT/platform-tools/* directory. If not, create a
symlink *$ANDROID_SDK_ROOT/platform-tools/dx* and point it to the dx 
tool from Android SDK build tools
- Run **./compile_utilities.sh** script
- Set the environment variables in the scripts:
  - common.sh
    - RUN_DIR = \<Path to store the local copy of Fuzzer\>
    - FILER_DIR = \<Path where the original Fuzzer is located\>
    - HOME_DIR = \<Path to local host builds, called $HOST_BUILDS in this readme\>
  - install_build_manual.sh
    - BUILDS_DIR = \<The same as above, directory to local host 
    builds, called $HOST_BUILDS in this readme\>
  - p.sh
    - FUZZER_ROOT_DIR = \<The same as FILER_DIR, path to the original Fuzzer\>
  - install_build.sh
    - WEBSHARE_BUILDS_DIR = \<Path to stored and archived builds\>
  - mrt.sh
    - ADDRESS = \<email address to send notifications to\> 
- Speedup opportunity
  - If you have a RAM disk, you can mount it to */export/ram* and the Fuzzer will 
  automatically use it for temp files, which gives a significant speedup.

## Android host build structure

For configuring the Android OS building environment, refer to 
[the link](https://source.android.com/source/index.html)

To make the Android host build, follow the steps from 
[android sources site](https://source.android.com/source/building.html) 
to build the image for emulator and add the following arguments for make command:
 
For 32-bit host build:
`WITH_HOST_DALVIK=true build-art-host libarttest_32 libnativebridgetest_32 
jasmin smali dexmerger hprof-conv`

For 64-bit host build:
`WITH_HOST_DALVIK=true BUILD_HOST_64bit=1 build-art-host libarttest libnativebridgetest jasmin smali dexmerger hprof-conv`

The structure of the build:

- \<top directory\> &larr; $ANDROID_BUILD_TOP should point here
  - out
    - host
      - common
        - obj
          - JAVA_LIBRARIES
      - linux-x86
        - bin
        - lib
        - lib32
        - lib64
        - usr
        - framework

After you performed the build, copy and compress to \<build-name\>_host.tgz archive the host 
build files from the tree above. Eventually, you should get the following structure:
- \<other top directory\> &larr; $WEBSHARE_BUILDS_DIR should point here
  - *branch1*
    - *build1*
      - aosp_x86-userdebug
        - WW10_host.tgz &larr; The archive with 32-bit build you've prepared
          - out
            - ...
      - aosp_x86_64-userdebug
        - WW10_host.tgz &larr; The archive with 64-bit build you've prepared
          - out
            - ...
    - *build2*
      - ...
  - *branch2*
    - *build1*
      - ...

After you run `./install_build.sh branch1 build1` you should get the following:
- \<some other directory\> &larr; $HOST_BUILDS should point here
  - *branch1*
    - *build1*
      - HOST-userdebug
        - out
          - ...
      - HOST_64-userdebug
        - out
          - ...

## The tool files description

### Scripts

- common.sh               - common part for the scripts related to running Fuzzer and 
generated tests
- mrt.sh                  - launches Fuzzer test cycle in host mode on multiple hosts 
in multiple processes
- rt.sh                   - runs Fuzzer tool and generated tests in a loop; re-runs 
generated tests in a given dir
- c.sh                    - runs Fuzzer-generated single test
- e.sh                    - runs experiments on Fuzzer-generated tests disabling 
optimization passes
- stat.sh                 - runs Fuzzer-generated tests on a set of Android builds
- sort.pl                 - combines results of e.sh and stat.sh in a single document
- p.sh                    - generates .tgz file with failing tests and run.sh for 
attaching it to a bug report
- run.sh                  - runs the tests being attached to a bug report
- install_build.sh        - installs the host build to a local machine from predefined 
location with builds. Usage: **./install_build.sh aosp-master WW10**
- install_build_manual.sh - installs the host build to a local machine from any 
location. Usage: **./install_build.sh \<general-path-to-builds\>/aosp-master/WW10**
- build-apk.sh            - builds and signs an apk with generated tests

### Java source files

- rb/FuzzerUtils.java
  - superclass for all generated tests; includes methods for initializing
arrays and calculating check sums
- rb/Test.java
  - simple class for getting all available compiler passes names, if possible
- apk/Fuzzer/src/com/intel/fuzzer/MainActivity.java
  - The entry point for running Fuzzer tests on device in JIT profile mode
- apk/Fuzzer/src/com/intel/fuzzer/TestRunner.java
  - Class to run the tests on a device in any mode (Commandline or from Activity)

### Ruby source files

- Fuzzer.rb - the entry point of the tool
- Basics.rb - Core abstractions described here (JavaClass, Array, Variable, Context).
- Config.rb - Fuzzer configuration, importing from YML files. 
- Statements.rb  - General Java statements generation
- ControlFlow.rb - *if-then-else*, *switch-case*, *continue-brake* statements support
- Exceptions.rb - Java exceptions and try-catch statements generation 
- Loops.rb      - loops statements
- Methods.rb    - Java Methods generation
- LibMethods.rb - special cases for Java Methods generation
- Vectorization.rb - Special cases for testing vectorization

## Weekly manual testing

Testing is performed on linux hosts.
Builds should be located in $HOST_BUILDS directory: **$HOST_BUILDS/$BRANCH/$BUILD**, 
e.g. **$HOST_BUILDS/aosp-master/WW10**

Steps before starting a test run:
1. Unpack and copy the target builds to $HOST_BUILDS/$BRANCH/$BUILD/HOST[_64]-usedrebug
2. Check HOME_DIR, RUN_DIR, FILER_DIR, SAVE_PASSED and DEVICE_MODE variables in common.sh
3. Set BRANCH, BUILD, BITS variables to match the build you want to test
4. Set ADDRESS variable in mrt.sh script (an email address to sent notifications to)
5. On a target machine:
`nice bash ./mrt.sh -R <results dir> -NT <number of tests for each thread> -NP <number of threads> -P <prefix> -A -i`
    
Add option `-S <number of hosts>` for the run on one host if you want to collect statistics and sort results.

### How to run the tool

Examples of running Fuzzer cycles:
`nice bash ./mrt.sh -NP 10 -NT 4000 -P t -R res/aosp-master/32`
    
Launches 10 processes, each of them generates 4K tests and runs them on an Android 
host build one by one. All the failed tests are stored in the *res/aosp-master/32* 
dir in crashes, fails, and hangs sub-dirs. Location of the Android build is specified 
by common.sh file. After the test runs are complete, statistics on the ART optimization 
passes and available builds are generated with e.sh, stat.sh, and sort.sh scripts for 
the tests from the crashes, fails, and hangs sub-dirs; resulting sorted files are 
placed in the *res/aosp-master/32* dir.

Typical commands for a weekly run:

On the first linux host: `nice bash ./mrt.sh -R res/aosp-master-WW10/32 -NT 40000 -NP 12 -P a -S 1 -A -i -bb 32`

On the second linux host: `nice bash ./mrt.sh -R res/aosp-master-WW10/64 -NT 40000 -NP 12 -P b -S 1 -A -i -bb 64`

Explanation of arguments used here:

| Arg  | Meaning | 
| ---- | ------- |
| -R   |  Save the results to the specified directory |
| -NT  | Number of tests to generate by each thread  |
| -NP  | Number of processes |
| -P   | Prefix for the test names |
| -S 1 | Collect the results statistics, tests were run on 1 host |
| -A   | Pass the rest arguments to rt.sh script |
| -i   | Compare the tests output with interpreter |
| -bb \<number\> | Test the 32 (64) bit build |

To run the testing in JIT mode:

On the first linux host: `nice bash ./mrt.sh -R res/aosp-master-WW[num]/32-jit -NT 40000 -NP 12 -P a -S 1 -A -i -bb 32 -jit`

On the second linus host: `nice bash ./mrt.sh -R res/aosp-master-WW[num]/64-jit -NT 40000 -NP 12 -P b -S 1 -A -i -bb 64 -jit`



## MM extension manual testing

MM (Memory management) extension can be enabled by editing config.yml file or 
using configMME.yml settings.
 - Change the "mode" to "MM" or "MM_extreme"
 - **Do not** pass '-d' argument to the Fuzzer.rb script
 - *Optional:* Increase TIMEOUT in common.sh or add -t <new_timeout> to rt.sh script
 - *Optional:* Add -Xmx512m option. This is not a default value, but allows more 
 memory-intensive tests not to fail with OOM

Example: `nice bash ./mrt.sh -NP 8 -NT 10000 -R res/MM_WW10 -A -gc -extreme -conf configMME.yml`

#### Explanation of arguments used here:

| Arg       | Meaning |
| --------- | ------  |
| -R        | Save the results to the specified directory |
| -NT       | Number of tests to generate by each thread |
| -NP       | Number of processes |
| -A        | Pass the rest arguments to rt.sh script |
| -gc       | adds random GC options during run |
| -extreme  | disables result comparison (this is needed for MM_extreme configuration, because generated tests are multi-threaded and could produce non-determenistic output) |
| -conf \<yml file\> | Use \<yml file\> for Fuzzer configuration |

Changes from the user point of view:
 - classes.dex file in the root of Fuzzer is a simple fake test to get the list 
 of optimization passes.
 - If e.sh scripts fails to get the list of passes, it uses the hardcoded one 
 (see the hardcoded list in e.sh)
 - When interpreter is killed due to timeout, current test is skipped, because 
 there is no reference output to compare with
 - When OOM is detected, test failure is ignored. Depending on configuration, 
 MM extension generates such tests sometimes.

The process of evaluation is unchanged. If collecting of statistics is enabled ('-S' option), 
corresponding stat files are created - fails-sorted.txt, crashes-sorted.txt, etc.

#### Basic MM extension settings (in yml configuration files):

| Parameter | Meaning |
| --------- | ------- |
| mode | 'default', 'jit', 'MM' and 'MM_extreme' values are supported. *default* and *jit* modes are used for regular testing, *MM* and *MM_extreme* intensify MM testing|
| p_big_array | probability of generating an array of size bigger than max_size |
| min_big_array       | min length of big array |
| max_big_array       | max length of big array |
| max_classes         | maximum number of generated classes. The actual number can be bigger due to foreign class fields generation |
| max_threads         | maximum number of new thread creation. Do not use it! Feature is under development |
| p_constructor       | probability of non-trivial constructor |
| max_callers_chain   | maximum length of a chain of methods calling each other. Too big value of this parameter can lead to too long tests execution |
| p_non_static_method | probability of generated method being not static |
| p_null_literal      | probability of assigning null to an Object variable |
| var_types           | different types of variable declaration. |

#### Var types description:

| Ver type | Meaning |
| -------- | ------- |
| non_static | non-static field of a current class |
| static | static field of a current class |
| local | local variable of a current method |
| static_other | static field of a foreign class, example: Class1.iFld |
| local_other | non-static field of an object of a foreign class, example: Object1.iFld |
| block | the variable is declared in current block (loop) |

Other new things:

- types               - two new types: Object and Array. Object variables can 
be objects of any generated class, all generated arrays are treated as Array 
                      variables and can be assigned/reassigned. Also, 
                      sub-arrays can be assigned/reassigned.
- op_cats             - two new categories: object_assn, array_assn
- statements          - one new statement kind - NewThreadStatement

## Running tests on device

Set ANDROID_SERIAL to a serial number of device you want to run tests on. 
(Type 'adb devices' to see which devices are connected to the host)
Set DEVICE_MODE variable in common.sh to 'on'. That's all - the rest 
scripts should work exactly as in host mode, even in multi-threaded mode

## Running tests in JIT_PROFILE mode on device

In this mode Fuzzer does the next steps for each iteration:
- generates -st \<number\> tests
- builds apk from generated tests
- installs apk
- repeats -si \<number\> times:
- runs the apk in interpreter mode, runs it as an application, compares output, 
forces the system to recompile the app using collected profile.

Steps to run the tests in JIT profile mode:
1. Set up the environment:
   export ANDROID_SDK_ROOT=<path to Android SDK>
   export ANDROID_SERIAL=<serial number of the device to run the tests on>
2. Use configJIT.yml settings by passing "-conf configJIT.yml" options to rt.sh script
3. Add "-apk" argument to rt.sh script
4. Other helpful rt.sh options are:
  - -st <number> - Number of subtests for apk-mode
  - -si <number> - Number of iterations for apk-mode
  - -mt <number> - Min milliseconds to execute apk
  - -o           - Pass -o option to Fuzzer and control the execution from outside

Example: `nice bash ./mrt.sh -NT 10000 -APK -R res/JIT_profile_WW10 -A -apk -jit -o -st 10 -si 5 -mt 23000 -t 600 -sp -conf configJIT.yml`

**Notes:**
- **Due to running an app with GUI this mode works only in one thread, -NP option will not work**
- **Execution time is quite long, to reduce it you can decrease -st and -mt parameters.**
**Also you can set smaller max_small_meth_calls parameter in yml config file** 

#### Explanation of arguments used here:

| Arg   | Meaning |
| ----- | ------- |
| -R    | Save the results to the specified directory |
| -NT   | Number of tests to generate by each thread |
| -APK  | Enable apk mode for mrt.sh script(will automatically set the number of processes to 1) |
| -A    | Pass the rest arguments to rt.sh script |
| -apk  | Enable the apk mode for rt.sh script |
| -jit  | Enable the jit mode |
| -o    | Vary the test execution by the outer parameter |
| -st   | Number of sub-tests included in each apk |
| -si   | Number of sub-iteration performed for the each apk |
| -mt   | Minimal time of apk execution in ms |
| -t    | Timeout for the each test |
| -sp   | Save passed tests |
| -conf | Use another Fuzzer configuration file (configJIT.yml tunes Fuzzer to generate JIT-stressing tests) |


## Authors
- Mohammad R. Haghighat (Intel Corporation)
- Dmitry Khukhro (Intel Corporation)
- Andrey Yakovlev (Intel Corporation)
