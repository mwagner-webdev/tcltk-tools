#!/usr/bin/env/tclsh
# Script to automatically clean out \index entries from LaTeX source
# Copyright 2009 Joakim Storck
# E-mail: joasto@gmail.com
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see .

set flf [open "indexfiles.txt" r]
set filelist [read $flf]
close $flf

file mkdir out

proc cleanidx {src outvar} {
    upvar $outvar target
    regsub -all {\|see\{([^\}]+)\}} $src "" src
    regsub -all {\\index\{([^\}]+)\}} $src "" target
}

foreach fnam $filelist {
    puts "Processing file $fnam"
    set sf [open $fnam r]
    set src [read $sf]
    close $sf
    cleanidx $src result
    set of [open "out/$fnam" w]
    puts $of $result
    close $of
}
