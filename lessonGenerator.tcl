package require sqlite3

proc writeToDB {input} {
    sqlite3 db twdb
    db eval {CREATE TABLE lessons(i INTEGER PRIMARY KEY, str text)}
    
    db eval {BEGIN}
    foreach item $input {
        db eval {INSERT INTO lessons values (NULL, $item)}
    }
    db eval {COMMIT}
    db close
}

if {$argc != 3} {
    puts "Invalid arguements. Should be,"
    puts "      tclsh lessonGenerator fileName minLength maxLength"
    exit
}

set fh [open [file join [lindex $argv 0]]]
set data [read $fh]
close $fh

set minLength [lindex $argv 1]
set maxLength [lindex $argv 2]


set match [split $data ".!"]
foreach item $match {
    set item [string trim $item]
    if {[string length $item] <= $maxLength && [string length $item] >= $minLength} {
        lappend canidateStrings $item
    }
}

writeToDB $canidateStrings

