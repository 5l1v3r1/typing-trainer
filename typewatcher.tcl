package require Tk


set sideBarHeight 500
set sideBarWidth 300

set barH 10
set bars [list [list 10 "red" 10] [list 20 "green" 10] [list 30 "green" 10] [list 40 "green" 10]]


for {set i 0} {$i < 80} {incr i} {
    set count [expr 6*$i]
    lappend bars  [list $count "green" 6]
}



proc updateBar {bar barNumber percent lbl} {
    global $bar

    lassign [lindex $::bars $barNumber] location color h
    catch {.c delete [set [set bar]]}
    set [set bar] [.c create rectangle [expr {$::sideBarWidth - 1}] $location [expr {$::sideBarWidth - int(1.0 * $percent * $::sideBarWidth)}] [expr {$location + $h}] -fill $color]

    if {[expr {$barNumber % 10}] == 0} {
        catch {.c delete "wpmLabel$barNumber"} 
        .c create text 5  [expr {$location + $h/2}] -text [expr {int($lbl)}] -tags "wpmLabel$barNumber" -fill white -font "Arial 14" -anchor w
    }
}


proc setGreen {} {
    .t tag add yellow "1.1 + $::currntCharIndex char" "1.2 + $::currntCharIndex char"
    .t tag add green "1.0 + $::currntCharIndex char" "1.1 + $::currntCharIndex char"
    .t configure -background "white"
    .t yview -pickplace "1.0 + [expr $::currntCharIndex + 200] char"
    .t yview -pickplace "1.0 + [expr $::currntCharIndex - 200] char"
}

proc recomputeRhyme {{in -1}} {
    if {$in == -1} {
        set delay [expr [clock milliseconds] - $::lastPressTime]
        set newDelayDiff [expr abs($delay - $::lastDelay)]
    } else {
        set delay $in
        set newDelayDiff [expr abs($delay - $::lastDelay)]
        set ::lastDelay $delay
            
        if {[llength $::delayDiffs] > 30} {
            set ::delayDiffs [lreplace $::delayDiffs 0 0]
        }
    }

   lappend ::delayDiffs $newDelayDiff

    set total 0
    foreach diff $::delayDiffs {incr total $diff}
    set ::rhyme [expr {$total / [llength $::delayDiffs] / 600.0}]
   
    if {$in == -1} {
        set ::delayDiffs [lreplace $::delayDiffs end end]
    }
    
    #updateBar rhymeMeter 0 $::rhyme
}


proc recomputeLLWPM {{timestamp -1}} {
    if {$timestamp == -1} {set timestamp [clock milliseconds]}
    set limit [expr {$timestamp - 60000}]
    for {set i 0} {$i < [llength $::wpmLog2]} {incr i} {
        if {[lindex $::wpmLog2 $i] < $limit} {
            set ::wpmLog2 [lreplace $::wpmLog2 $i $i]
            incr i -1
        } else {
            break
        }
    }

    set ::wpmLabel [expr {[llength $::wpmLog2]/5}]
    #updateBar wpmMeter3 3 [expr {$::wpmLabel / 100.0}]
}

proc recomputeLWPM {{timestamp -1}} {
    if {$timestamp == -1} {set timestamp [clock milliseconds]}
    set limit [expr {$timestamp - 12000}]
    for {set i 0} {$i < [llength $::wpmLog]} {incr i} {
        if {[lindex $::wpmLog $i] < $limit} {
            set ::wpmLog [lreplace $::wpmLog $i $i]
            incr i -1
        } else {
            break
        }
    }

    set wpmLabel [llength $::wpmLog]
    #updateBar wpmMeter2 2 [expr {$wpmLabel / 100.0}]
}

proc recomputeWPM {timestamp} {
    set diff [expr $timestamp - $::lastPressTime]
    set wpmLabel [expr {12000.0/$diff}]
    #updateBar wpmMeter 1 [expr {$wpmLabel/100.0}]
}

proc updater {} {
    set diff [expr [clock milliseconds] - $::lastPressTime]

    recomputeLWPM
    recomputeRhyme
    recomputeLLWPM

    computeCoolness

    after 50 updater
}


proc computeCoolness {} {
    set timestamp [clock milliseconds]
    # fix this needless looping
    for {set i 1} {$i < 80} {incr i} {
        set j 0
        for {} {$j < [llength $::wpmLog2]} {incr j} {
            if {[lindex $::wpmLog2 $j] > [expr $timestamp - (1000*$i)]} {
                break
            }
        }

        set wpmLabel [expr {([llength $::wpmLog2] - $j)/($i/12.0)}]

        updateBar "wpm[expr $i + 3]" [expr $i + 3] [expr {$wpmLabel / 100.0}] $wpmLabel
    }
}


proc press {char} {
    set pressTime [clock milliseconds]
    set currentChar [string index $::textToType $::currntCharIndex]

    if {$char == $currentChar || ($currentChar == "\n" && [string trim $char] == "")} {
        setGreen
        incr ::currntCharIndex
        if {$::lastCharPressed != -1} {
            set diff [expr $pressTime - $::lastPressTime]
            lappend ::pairs($::lastCharPressed$char) $diff 
            lappend ::singles($char) $diff
            lappend ::wpmLog $pressTime
            lappend ::wpmLog2 $pressTime

            recomputeRhyme $diff
            recomputeWPM $pressTime
            
            set rh [open rhyme.txt "a+"]
            puts $rh "$char,$diff"
            close $rh
        }

        set ::lastPressTime $pressTime
        set ::lastCharPressed $char


    } else {
        set fh [open errors.txt "a+"]
        puts $fh "\"$currentChar\",\"$char\""
        close $fh

        incr ::errors
        .t configure -background "red"
    }
}

proc save {} {
    set fh [open pairs.txt "w"]
    foreach pair [array names ::pairs] {
        puts -nonewline $fh "@$pair"
        foreach stamp $::pairs($pair) {
            puts -nonewline $fh "@$stamp"
        }
        puts $fh ""
    }
    close $fh

    set fh [open singles.txt "w"]
    foreach single [array names ::singles] {
        puts -nonewline $fh "@$single"
        foreach stamp $::singles($single) {
            puts -nonewline $fh "@$stamp"
        }
        puts $fh ""
    }
    close $fh
    exit
}


set currntCharIndex [lindex $argv 0]
set errors 0

set lastPressTime -1
set lastCharPressed -1

set fh [open txt.txt]
set textToType [read $fh]
close $fh

set rhyme 0
set wpmLabel 0
set lastDelay 0
set wpmLog ""
set wpmLog2 ""

text .t -width 50 -height 30
canvas .c -background black -width $sideBarWidth -height $sideBarHeight
canvas .c2 -background black -width $sideBarWidth -height $sideBarHeight


grid .c .t .c2
#grid columnconfigure . {0 1 2}

label .wpm -textvariable wpmLabel



#updateBar rhymeMeter 0 0.5
#updateBar wpmMeter 1 0.5
#updateBar wpmMeter2 2 0.5
#updateBar wpmMeter3 3 0.5

.t insert 1.0 $textToType
.t configure -state disable

.t tag add green 1.0 1.0
.t tag configure yellow -background "yellow"
.t tag configure green -background "green"
.t tag raise green


setGreen
incr ::currntCharIndex


foreach char [list Return space Key-minus Key-_ Key-0 Key-1 Key-2 Key-3 Key-4 Key-5 Key-1 6 7 8 9 ! @ # $ % ^ & * ? = + ' , . p y f g c r l a o e u i d h t n \; : q j k x b m w v z P Y F G C R L A O E U I D H T N S Q J K X B M W V Z S s ( )] {
    bind . <$char> {press %A}
}

bind . <Control-q> {save}

updater
