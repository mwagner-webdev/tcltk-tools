#!/usr/bin/env tclsh
# LiXTcl.tcl
# LaTeX indexer in Tcl
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
set wdf [open "indexwords.txt" r]
set wordlist [split [read $wdf] \n]
close $wdf
 
file mkdir out
 
set noindex [list caption chapter cite includegraphics index item label pageref ref section subsection]
 
set indexbefore [list gls glsfirst glsfirstplural glslink glsplural]
 
proc addidx {src word outvar} {
    upvar $outvar target
    global _see
    if {[regexp {([[:print:]]+)(?: *-> *)([[:print:]]+)} $word match first second]} {
        set first [string trim $first]
        set second [string trim $second]
        regsub -all $first $src \\index{$second}& target
    } elseif {[regexp {([[:print:]]+)(?: *\| *)([[:print:]]+)} $word match first second]} {
        set first [string trim $first]
        set second [string trim $second]
        if { [catch {set _see($first)}] } {
            if {[regsub $first $src \\index{$first\|see{$second}}& target]} {
                set _see($first) 1
            }
        } else {
            set target $src
        }
    } else {
        regsub -all $word $src \\index{&}& target
    }
}
 
proc addidxbefore {macrosrc src word outvar} {
    upvar $outvar target
    global _see
    set target $macrosrc
    if {[regexp {([[:print:]]+)(?: *-> *)([[:print:]]+)} $word match first second]} {
        set first [string trim $first]
        set second [string trim $second]
        if {[string first $first $src]>=0} {
            set target \\index{$second}$macrosrc
        }
    } elseif {[regexp {([[:print:]]+)(?: *\| *)([[:print:]]+)} $word match first second]} {
        # Cross references ("x, see y")
        set first [string trim $first]
        set second [string trim $second]
        if {[string first $first $src]>=0} {
            if { [catch {set _see($first)}] } {
                set target \\index{$first\|see{$second}}$macrosrc
                set _see($first) 1
            } else {
                set target $macrosrc
            }
        }
    } elseif {[string first $word $src]>=0} {
        set target \\index{$word}$macrosrc
    }
}
 
proc matchparen {srcvar from to} {
    upvar $srcvar src
    upvar $to where
    set level 0
    set where $from
    while {true} {
        set leftmatch [regexp -indices -start $where -- {\{} $src nxtleft]
        set rightmatch [regexp -indices -start $where -- {\}} $src nxtright]
        set nxtleft [lindex $nxtleft 0]
        set nxtright [lindex $nxtright 0]
        if {$leftmatch && $nxtleft < $nxtright} {
            incr level
            set where [expr $nxtleft+1]
        } else {
            incr level -1
            set where [expr $nxtright+1]
        }
        if {$level <= 0} {
            incr where -1
            break
        }
    }
}
 
proc nextmacro {src where macroname} {
    upvar $macroname keywd
    set keywd ""
    lassign [regexp -inline -nocase -start $where -- \
        {\\([a-z]+?)(\[([[:print:]]*?)\])?([\{[:space:]])} $src] match keywd param paramval leftpar
    regexp -indices -nocase -start $where -- {\\([a-z]*?)(\[([[:print:]]*?)\])?([\{[:space:]])} $src where
    set xpbegin [lindex $where 0]
    set parbegin [lindex $where end]
    if {[string equal $leftpar "\{"]} {
        matchparen src $parbegin parend
    } else {
        set parend $parbegin
    }
    return [list $xpbegin $parbegin $parend]
}
 
foreach fnam $filelist {
    puts "Processing file $fnam"
    set sf [open $fnam r]
    set src [read $sf]
    close $sf
    foreach word $wordlist {
		if {[string length $word]==0} {
			# Skip empty rows
			continue
		}
        set result ""
        set where 0
        while {true} {
            lassign [nextmacro $src $where keywd] macrobegin parbegin parend
            if {[string length $keywd]>0} {
                addidx [string range $src $where [expr $macrobegin-1]] $word outstr
                append result $outstr
                set where $macrobegin
                if {[string first [string tolower $keywd] $noindex]>=0} {
                    # Do not index inside this macro!
                    # Output source until end of macro
                    # and forward search point to there.
                    append result "[string range $src $where $parend]"
                    set where [expr $parend+1]
                } elseif {[string first [string tolower $keywd] $indexbefore]>=0} {
                    # Put index outside (before) this macro!
                    append result "[string range $src $where $macrobegin-1]"
                    set macrosrc [string range $src $macrobegin $parend]
                    set parsrc [string range $src $parbegin $parend]
                    addidxbefore $macrosrc $parsrc $word outstr
                    append result $outstr
                    set where [expr $parend+1]
                } else {
                    # Index inside this macro.
                    # Forward to inside left parenthesis
                    addidx [string range $src $where $parbegin] $word outstr
                    append result $outstr
                    set where [expr $parbegin+1]
                }
				continue
            } 
			append result [string range $src $where end]
            break
        }
        set src $result
    }
    set of [open "out/$fnam" w]
    puts $of $result
    close $of
}
