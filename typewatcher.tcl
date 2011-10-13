package require Tk


set errorResolution 20.0
set timeStep 250
set sideBarHeight 500
set sideBarWidth 300

for {set i 0} {$i < 81} {incr i} {
    set count [expr 6*$i]
    lappend bars  [list $count "green" 6 "wpmBar$i" "wpmLabel$i" "w" ".c"]
    lappend bars2  [list $count "red" 6 "errorBar$i" "errorLabel$i" "e" ".c2"]
}

proc updateBar {barNumber percent lbl} {
    lassign [lindex $::bars $barNumber] y color h
    .c delete  "wpmBar$barNumber"
    .c create rectangle [expr {$::sideBarWidth - 1}] $y [expr {$::sideBarWidth - int($percent * $::sideBarWidth)}] [expr {$y + $h}] -fill $color -tags "wpmBar$barNumber"


    if {[expr {$barNumber % 10}] == 0} {
        catch {.c delete "wpmLabel$barNumber"}
        .c create text 5  [expr {$y + $h/2}] -text [expr {int($lbl)}] -tags "wpmLabel$barNumber" -fill white -font "Arial 14" -anchor w
    }
}

proc updateErrorSubBar {barNumber percent lbl} {
    lassign [lindex $::bars2 $barNumber] y color h
    .c2 delete  "errorBar$barNumber"
    .c2 create rectangle 0 $y [expr {int(1.0 * $percent * $::sideBarWidth)}] [expr {$y + $h}] -fill $color -tags "errorBar$barNumber"
    if {[expr {$barNumber % 10}] == 0} {
        catch {.c2 delete "errorLabel$barNumber"} 

        .c2 create text [expr $::sideBarWidth - 5]  [expr {$y + $h/2}] -text [expr {int($lbl)}] -tags "wpmLabel$barNumber" -fill white -font "Arial 14" -anchor e -tags "errorLabel$barNumber"
    }
}

proc setGreen {} {
    .t tag add yellow "1.1 + $::currntCharIndex char" "1.2 + $::currntCharIndex char"
    .t configure -background "white"
    .t yview -pickplace "1.0 + [expr $::currntCharIndex + 200] char"
    .t yview -pickplace "1.0 + [expr $::currntCharIndex] char"
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
    set ::rhyme [expr {$total / [llength $::delayDiffs]}]
   
    if {$in == -1} {
        set ::delayDiffs [lreplace $::delayDiffs end end]
    }

    .c3 delete $::rhymeBar
    set ::rhymeBar [.c3 create rectangle [expr {500 - $::rhyme / 2}] 65 [expr {500 + $::rhyme / 2}] 60 -fill "yellow"]
}


proc updater {} {
    set diff [expr [clock milliseconds] - $::lastPressTime]

    recomputeRhyme
    updateErrorBar
    updateWpmBar

    after 100 updater
}


proc updateErrorBar {} {
    set timestamp [clock milliseconds]
    set limit [expr $timestamp - 80*$::timeStep]
    while {[llength $::lastErrors] > 0 && [lindex [lindex $::lastErrors 0] 0] < $limit} {
        set ::lastErrors [lreplace $::lastErrors 0 0]
    }

    set j 0
    for {set i 80} {$i > 0} {incr i -1} {
        set limit [expr $timestamp - ($::timeStep*$i)]
        for {} {$j < [llength $::lastErrors]} {incr j} {
            if {[lindex [lindex $::lastErrors $j] 0] > $limit} {break}
        }

        set temp [expr {([llength $::lastErrors] - $j)}]
        updateErrorSubBar $i [expr {$temp / $::errorResolution}] $temp
    }
}


proc updateWpmBar {} {
    set timestamp [clock milliseconds]
    set limit [expr $timestamp - 80*$::timeStep]
    
    while {[llength $::wpmLog] > 0 && [lindex $::wpmLog 0] < $limit} {
        set ::wpmLog [lreplace $::wpmLog 0 0]
    }

    set wpmLogLength [llength $::wpmLog]
    
    set j 0
    for {set i 79} {$i > 0} {incr i -1} {
        set limit [expr $timestamp - ($::timeStep*$i)]
        for {} {$j < $wpmLogLength} {incr j} {
            if {[lindex $::wpmLog $j] > $limit} {break}
        }


        set wpmLabel [expr {($wpmLogLength - $j)*(1000/$::timeStep)/($i/12.0)}]

        if {[expr {$::timeStep * $i}] == 10000} {
            .c3 itemconfigure $::speedLabel -text "[expr {int($wpmLabel)}] WPM"
        }
        updateBar $i [expr {$wpmLabel / 100.0}] $wpmLabel
    }
}


proc press {char} {
    set pressTime [clock milliseconds]
    set currentChar [string index $::textToType $::currntCharIndex]

    if {$char == $currentChar || ($currentChar == "\n" && [string trim $char] == "")} {
        incr ::total
        if {!$::lastPressWasError} {
            .t tag add green "1.0 + $::currntCharIndex char" "1.1 + $::currntCharIndex char"
            incr ::correct
        } else {
            set ::lastPressWasError false
            .t tag add red "1.0 + $::currntCharIndex char" "1.1 + $::currntCharIndex char"

        }
        .c3 itemconfigure $::accuracyLabel -text "[expr {int((100.0 * $::correct) / $::total)}]%"

        setGreen
        incr ::currntCharIndex
        if {$::lastCharPressed != -1} {
            set diff [expr $pressTime - $::lastPressTime]
            lappend ::pairs($::lastCharPressed$char) $diff 
            lappend ::singles($char) $diff
            lappend ::wpmLog $pressTime

            recomputeRhyme $diff
            
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

        lappend ::lastErrors [list $pressTime $currentChar]
       
        incr ::total
        .c3 itemconfigure $::accuracyLabel -text "[expr {int((100.0 * $::correct) / $::total)}]%"

        set ::lastPressWasError true

        incr ::errors
        .t configure -background "orange"
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


set errors 0

set correct 0
set total 0

set lastPressTime -1
set lastCharPressed -1

set fh [open txt.txt]
set textToType [read $fh]
close $fh

set rhyme 0
set lastDelay 0
set wpmLog ""
set lastErrors ""
set delayDiffs ""

set rhymeBar ""

set ::lastPressWasError false

text .t -width 50 -height 30
canvas .c -background black -width $sideBarWidth -height $sideBarHeight
canvas .c2 -background black -width $sideBarWidth -height $sideBarHeight
canvas .c3 -background black -width 1000 -height 70

grid .c .t .c2
grid .c3 -columnspan 3


.t insert 1.0 $textToType
.t configure -state disable

.t tag add green 1.0 1.0
.t tag configure yellow -background "yellow"
.t tag configure green -background "green"
.t tag configure red -background "dark green"
.t tag raise green

set accuracyLabel [.c3 create text [expr {1000 - $sideBarWidth}] 0 -anchor ne -text "100%" -fill white -font "Arial 20"]
set speedLabel [.c3 create text $sideBarWidth 0 -anchor nw -text "0 WPM" -fill white -font "Arial 20"]


foreach char [list Return space Key-minus Key-_ Key-0 Key-1 Key-2 Key-3 Key-4 Key-5 Key-1 6 7 8 9 ! @ # $ % ^ & * ? = + ' , . p y f g c r l a o e u i d h t n \; : q j k x b m w v z P Y F G C R L A O E U I D H T N S Q J K X B M W V Z S s ( )] {
    bind . <$char> {press %A}
}

bind . <Control-q> {save}

if {[llength $argv] != 1} {
    set currntCharIndex -1
} else {
    set currntCharIndex [lindex $argv 0]
    setGreen
}

incr ::currntCharIndex
updater


