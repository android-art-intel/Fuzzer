#!/usr/bin/perl

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

#-------------------------------------------------------------------
# Parses the list of failing tests and sort them out based on signatures.
# Arguments:
# -pf <path> - path to the file - list of test results ()
# -bf <path> - path to the file - result of stat.sh
# ? 1 - path to the dir of the tests
#-------------------------------------------------------------------
$DEL = "#";

&init();

logIt("sort.pl: This may take a few minutes... ");

defined $pass_file  and %pres = &parse($pass_file);
defined $build_file and %bres = &parse($build_file);
defined $pass_file  and defined $build_file and %res = &combineLists();

!%res and defined $pass_file  and %res = %pres;
!%res and defined $build_file and %res = %bres;

logIt("Groups count: ".keys(%res));

foreach $k (keys(%res)) {
    #next if $res{$k} eq "";
    print "-----------------------------------------------------";
    print join("\n", split($DEL, $k));
    print "\n    ".$res{$k}."\n";
}

logIt(" ...all done\n");

exit 0;


sub logIt {
#-------------------------------------------------------------------
# Print a message to the log stream. Argument:
#     0 - message to be printed
#-------------------------------------------------------------------
    print STDERR @_;
}

sub stop {
#-------------------------------------------------------------------
# Print diagnostics and quit the script
#-------------------------------------------------------------------
    die "ERROR: ", @_, "\n"
}

sub init {
#-------------------------------------------------------------------
# Check arguments, set variables
#-------------------------------------------------------------------
    $_ = shift @ARGV;
    while ($_) {
        /^-pf$/ and do {$pass_file  = shift @ARGV; next;};
        /^-bf$/ and do {$build_file = shift @ARGV; next;};
        &stop("Invalid argument: $_");
    } continue {
        $_ = shift @ARGV;
    }
    defined  $pass_file  or defined $build_file or &stop("No file to process");
    !defined $pass_file  or -f $pass_file  or &stop("List of opt pass results does not exist: $pass_file");
    !defined $build_file or -f $build_file or &stop("List of build results does not exist: $build_file");
}

sub parse {
#-------------------------------------------------------------------
# Parse file of results
#-------------------------------------------------------------------
    my ($fpath, %groups, $key, $test_id) = @_;
    open(LIST, $fpath) or &stop("Cannot open file: $fpath");
    while (<LIST>) {
        chomp;
        s/^\s+|\s+$//g;
        next if $_ eq "";
        #/^(.+\S)\s*$/;
        #$_ = $1;
#logIt("_ = ".$_."\n");
        if (/^---/) { # info on the next test begins
#logIt("key = ".$key."\n");
            defined $key and $groups{$key} .= " ".$test_id;
            /\s(\S+)$/;
            $test_id = $1;
            $key = "";
            next;
        }
        #/^(.+)\s+-/;
        #$key .= $DEL.$1;
        $key .= $DEL.$_;
    }
    close(LIST);
    $groups{$key} .= " ".$test_id;
    %groups
}

sub combineLists {
#-------------------------------------------------------------------
# Combine results for options with the results for builds and produce new groups list
#-------------------------------------------------------------------
    my %mark, %cmb, @tlist;
    foreach $opts (keys(%pres)) {
#logIt("\nopts = ".$opts."\n");
        @ptests = split(" ", $pres{$opts});
#logIt("ptests = ".$#ptests."\n");
        foreach $builds (keys(%bres)) {
#logIt("\nbuilds = ".$builds."\n\n");
            undef %mark;
            grep($mark{$_}++, @ptests);
            @tlist = grep($mark{$_}, split(" ", $bres{$builds}));
#logIt("tlist = ".$#tlist."\n");
            #$cmb{$opts.$DEL.$builds} .= join(" ", grep($mark{$_}, split(" ", $bres{$builds})));
            $cmb{$opts.$DEL.$builds} .= join(" ", @tlist) if $#tlist > -1;
        }
    }
    %cmb
}
