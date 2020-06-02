#-
# Copyright (c) 2020 Joshua Settle <joshuabsettle@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# Simplying Cisco Packet Capture.


proc progressbar {cur tot count} {
    # if you don't want to redraw all the time, uncomment and change ferquency
    #if {$cur % ($tot/300)} { return }
    # set to total width of progress bar
    set total 76
    set half [expr {$total/2}]
    set percent [expr {100.*$cur/$tot}]
    set val (\ [format "%6.2f%%" $percent]\ )
    #set str "[string repeat \b 50] ) |[string repeat = [
    #            expr {round($percent*$total/100)}]][
    #                    string repeat { } [expr {$total-round($percent*$total/100)}]]| [string repeat \b 52]"
    #set str "[string range $str 0 $half]$val[string range $str [expr {$half+[string length $val]-1}] end]"
    set str "|[string repeat = [expr {round($percent*$total/100)}]][string repeat { } [expr {$total-round($percent*$total/100)}]]|[string repeat \b 110]"
    set str "$val [string range $str 0 $half][string range $str [expr {$half+[string length $val]-1}] end]"
    puts -nonewline stderr $str
}


proc main {version protocol ipsource {ipdest any} {sinterface nothing} {duration {}} {size {}} } {
    ios_config "line vty 0 15" "international"
    puts "\x1B\x5B\x32\x4A\x1B\x5B\x30\x3B\x30\x48"
    if {$sinterface == "nothing"} {
        puts "\nCapture Type:\n  1.\) Interface \[default\]\n  2.\) Control-Plane"
        puts -nonewline "\nSelection: "
        flush stdout
        gets stdin {ctype}
        switch $ctype {
            "1" {set ctype "Interface"} 
            "2" {set ctype "control"} 
            default {set ctype "Interface"}}
        # get list of interfaces
        if {$ctype == "Interface"} { 
             puts "\nAvailable Interfaces:"
             set foundinterfaces [regexp -all -inline {[A-Za-z]+[\d/]+} [exec "show interface status"]]
             foreach {a b c d e f g h} [join $foundinterfaces ", "] {puts "$a $b $c $d $e $f $g $h"} 
             set i 0
             puts " "
             while {$i < 1} {
                puts "Which interface to packet capture \[exact syntax needed\]?"
                puts -nonewline "\nSelection: "
                flush stdout
                gets stdin {sinterface}
                if {$sinterface == "exit"} {incr i} else {}
                if {$i > 0} {continue} else {}
                if {[lsearch -exact $foundinterfaces $sinterface] == -1} { puts "\nInterface Not found...\n"} else {incr i}
                }
        }
    } else {
    switch -glob $sinterface {
      [c|C]ontrol* {set ctype control}
      default {set ctype Interface}
      }}
 
    if { $duration == {} || $size == {} } {
      if {$duration == {}} {
           puts -nonewline "\nHow long to run capture? <1-300 seconds> \[Default=60\] : "
           flush stdout
           gets stdin {duration}
              if {[string trim $duration] > 0} {
                } else {set duration 60;}
      }
      if {$size == {}} {
          puts -nonewline "\nMax Capture size? <1-50 MB> \[Default=30\] : "
          flush stdout
          gets stdin {size}
          if {[string trim $size] > 0} {} else {set size 30}
          }
      startcapture $version $protocol $ipsource $ipdest $ctype $sinterface $duration $size
    } else {
    startcapture $version $protocol $ipsource $ipdest $ctype $sinterface $duration $size
    }
}

proc versionsearch {version protocol ipsource ipdest ctype sinterface duration size} {
    switch -glob $version {
       9* {capture_commands9000 $protocol $ipsource $ipdest $ctype $sinterface $duration $size}
       38* {capture_commands3800 $protocol $ipsource $ipdest $ctype $sinterface $duration $size}
       3* {capture_commands3000 $protocol $ipsource $ipdest $ctype $sinterface $duration $size}
       default {puts "Unsupported Version!"}
      }
  }


proc startcapture {version protocol ipsource ipdest ctype sinterface duration size} {
      puts "\n"
      puts [string repeat - 37]
      if {$sinterface != "nothing"} {
        puts "Capture $sinterface \nDuration: $duration Sec \nFile Size: $size MB"
        } else {
        puts "Capture Type: Control-Plane \nDuration: $duration Sec \nFile Size: $size MB"
        }
      if { $ipsource == "any" && $ipdest == "any" } {
        puts "Capture ACL: $protocol any any"
      } else {
          puts "Capture ACL: $protocol $ipsource $ipdest \n             $protocol $ipdest $ipsource"
      }
      puts "Capture location: flash:CAPTURE.pcap"
      puts [string repeat - 37]
      puts ""
      puts -nonewline "Start? \[yes\|no\]: "
      flush stdout
      gets stdin {start}
      switch -glob $start {
        y* {versionsearch $version $protocol $ipsource $ipdest $ctype $sinterface $duration $size}
        default {
          puts "\nCanceling!"
        }
      }
    }
  
      
    

proc capture_commands3000 { protocol ipsource ipdest ctype sinterface duration size} {
  exec "monitor capture point stop all"
  ios_config "no access-list 199" 
  ios_config "access-list 199"
  if { $ipsource == "any" && $ipdest == "any" } {
        set any_s_d " permit $protocol any any"
  } else {
        if { $ipsource != "any" && $ipdest != "any" } {
           if { $protocol == "tcp" || $protocol == "udp" } {
                    if { [regexp -nocase {\:} $ipsource] && [regexp -nocase {\:} $ipdest] } {
                          set sourcesplit [ split $ipsource {:} ]
                          set destsplit [ split $ipdest {:} ]
                          set source_dest "permit $protocol host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] host [lindex $destsplit 0] eq [lindex $destsplit 1]"
                          set dest_source "permit $protocol host [lindex $destsplit 0] eq [lindex $destsplit 1] host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                          
                    } else { 
                         if { [regexp -nocase {\:} $ipsource] || [regexp -nocase {\:} $ipdest] } {
                                  if { [regexp -nocase {\:} $ipsource] } {
                                         set sourcesplit [ split $ipsource {:} ]
                                         set source_dest "permit $protocol host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] host $ipdest"
                                         set dest_source "permit $protocol host $ipdest host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                                 } else {
                                         set destsplit [ split $ipdest {:} ]
                                         set source_dest "permit $protocol host [lindex $destsplit 0] eq [lindex $destsplit 1] host $ipsource"
                                         set dest_source "permit $protocol host $ipsource host [lindex $destsplit 0] eq [lindex $destsplit 1]"
                                        }
                                 }
                            }
             } else {
                     set source_dest "permit ip host $ipsource host $ipdest"
                     set dest_source "permit ip host $ipdest host $ipsource"
                    }
           
  
      } else {
            if { $ipsource == "any" && $ipdest != "any" } {
              if { $protocol == "tcp" || $protocol == "udp" } {
                  if { [regexp -nocase {\:} $ipdest ] } {
                       set destsplit [ split $ipdest {:} ]
                       set f 8
                       set dest_source "permit $protocol $ipsource host [lindex $destsplit 0] eq [lindex $destsplit 1]"
                    if {[regexp -nocase {any} $ipdest]} {
                      set g 9
                       set source_dest "permit $protocol $ipsource [lindex $destsplit 0] eq [lindex $destsplit 1]"
                       
                    } else {
                      set g 10
                       set source_dest "permit $protocol host [lindex $destsplit 0] eq [lindex $destsplit 1] $ipsource"

                    }
                  } else {
                       set source_dest " permit $protocol any host $ipdest"
                       set dest_source " permit $protocol host $ipdest any"
                  }
              
              } else {
                set source_dest "permit ip any host $ipdest"
                set dest_source "permit ip host $ipdest any"
              }
            } else {
              if { $protocol == "tcp" || $protocol == "udp" } {
                if { [regexp -nocase {\:} $ipsource ] } {
                    set sourcesplit [ split $ipsource {:} ]
                    set f 4
                    set source_dest "permit $protocol host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] any"
                    if {[regexp -nocase {any} $ipsource]} {
                        set dest_source "permit $protocol any [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                        set g 3
                    } else {
                        set dest_source "permit $protocol any host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                      set g 5
                    }
                } else {
                    set source_dest " permit $protocol any host $ipsource"
                    set dest_source " permit $protocol host $ipsource any"
                    }
              } else {
                set source_dest "permit ip host $ipsource any"
                set dest_source "permit ip $ipdest any host $ipsource"
              }
            }
      }
  }

  if {[info exists any_s_d]} {
      ios_config "access-list 199 $any_s_d"
  } else {
    puts "$source_dest | $dest_source"
    ios_config "access-list 199 $source_dest"
    ios_config "access-list 199 $dest_source"

  }
  #if { $ipsource != "any" || $ipdest != "any" } {
  #   ios_config "access-list 199 permit ip host $ipsource host $ipdest"
  #   ios_config "access-list 199 permit ip host $ipdest host $ipsource"
  #} else {
  #  if { $ipsource == "any" && $ipdest != "any" } {
  #    ios_config "access-list 199 permit ip any host $ipdest"
  #    ios_config "access-list 199 permit ip host $ipdest any"
  #  } else {
  #  if { $ipsource != "any" && $ipdest == "any" } {
  #    ios_config "access-list 199 permit ip any host $ipsource"
  #    ios_config "access-list 199 permit ip host $ipsource any"
  #  } else {
  #    if { [catch {ios_config "access-list 199 permit ip any any"} result] } {
  #      puts "$result"
  #    }
  #    ios_config "access-list 199 permit ip any any"
  #    }
  #  }
  #}
  exec "monitor capture buffer BUFF linear"
  exec "monitor capture buffer BUFF filter access-list 199"
  set buffsize [expr $size * 1000]
  exec "monitor capture buffer BUFF size $buffsize"
  # <256-102400 Kbytes>
  exec "monitor capture buffer BUFF limit duration $duration"
  # <1-2000 sec>
  exec "monitor capture buffer BUFF max-size 1600"
  if {$ctype == "control"} {
  exec "monitor capture point ip process-switched POINT both"
  } else { 
    exec "monitor capture point ip cef POINT $sinterface both" 
    }
  exec "monitor capture point associate POINT BUFF"
  # <wait> show monitor capture buffer BUFF parameters
  # <wait> or show monitor capture buffer BUFF dump
  exec "monitor capture point start POINT"
  set total $duration
  for {set i 0 } {$i <= $total} {incr i} {if {$i == 0} {puts "Starting!\n"}; progressbar $i $total $duration; flush stdout ; after 1000; incr duration -1}
  puts ""
  set check [exec "show monitor capture point POINT"]
  set stop 0
  while {$stop < 2} {
  if {[regexp {Inactive} $check]} {
      set stop 3;
      } else {puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture point POINT"]; incr stop}
  }
  puts "Exporting capture to flash:CAPTURE.pcap"
  exec "monitor capture point stop POINT"
  #exec "monitor capture point stop all"
 
  exec "monitor capture buffer BUFF export flash:CAPTURE.pcap"
  if {$ctype == "control"} {
  exec "no monitor capture point ip process-switched POINT both"
  } else {
    exec "no monitor capture point ip cef POINT $sinterface both"
  }
  exec "no monitor capture buffer BUFF"
  puts "\nDone!\n"
  finish_statement
}

proc capture_commands9000 { protocol ipsource ipdest ctype sinterface duration size} {
    if { $ipsource == "any" && $ipdest == "any" } {
        set any_s_d " permit $protocol any any"
    } else {
        if { $ipsource != "any" && $ipdest != "any" } {
           if { $protocol == "tcp" || $protocol == "udp" } {
                    if { [regexp -nocase {\:} $ipsource] && [regexp -nocase {\:} $ipdest] } {
                          set sourcesplit [ split $ipsource {:} ]
                          set destsplit [ split $ipdest {:} ]
                          set source_dest "permit $protocol host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] host [lindex $destsplit 0] eq [lindex $destsplit 1]"
                          set dest_source "permit $protocol host [lindex $destsplit 0] eq [lindex $destsplit 1] host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                          
                    } else { 
                         if { [regexp -nocase {\:} $ipsource] || [regexp -nocase {\:} $ipdest] } {
                                  if { [regexp -nocase {\:} $ipsource] } {
                                         set sourcesplit [ split $ipsource {:} ]
                                         set source_dest "permit $protocol host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] host $ipdest"
                                         set dest_source "permit $protocol host $ipdest host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                                 } else {
                                         set destsplit [ split $ipdest {:} ]
                                         set source_dest "permit $protocol host [lindex $destsplit 0] eq [lindex $destsplit 1] host $ipsource"
                                         set dest_source "permit $protocol host $ipsource host [lindex $destsplit 0] eq [lindex $destsplit 1]"
                                        }
                                 }
                            }
             } else {
                     set source_dest "permit ip host $ipsource host $ipdest"
                     set dest_source "permit ip host $ipdest host $ipsource"
                    }
           
  
      } else {
            if { $ipsource == "any" && $ipdest != "any" } {
              if { $protocol == "tcp" || $protocol == "udp" } {
                  if { [regexp -nocase {\:} $ipdest ] } {
                       set destsplit [ split $ipdest {:} ]
                       set f 8
                       set dest_source "permit $protocol $ipsource host [lindex $destsplit 0] eq [lindex $destsplit 1]"
                    if {[regexp -nocase {any} $ipdest]} {
                      set g 9
                       set source_dest "permit $protocol $ipsource [lindex $destsplit 0] eq [lindex $destsplit 1]"
                       
                    } else {
                      set g 10
                       set source_dest "permit $protocol host [lindex $destsplit 0] eq [lindex $destsplit 1] $ipsource"

                    }
                  } else {
                       set source_dest " permit $protocol any host $ipdest"
                       set dest_source " permit $protocol host $ipdest any"
                  }
              
              } else {
                set source_dest "permit ip any host $ipdest"
                set dest_source "permit ip host $ipdest any"
              }
            } else {
              if { $protocol == "tcp" || $protocol == "udp" } {
                if { [regexp -nocase {\:} $ipsource ] } {
                    set sourcesplit [ split $ipsource {:} ]
                    set f 4
                    set source_dest "permit $protocol host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] any"
                    if {[regexp -nocase {any} $ipsource]} {
                        set dest_source "permit $protocol any [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                        set g 3
                    } else {
                        set dest_source "permit $protocol any host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                      set g 5
                    }
                } else {
                    set source_dest " permit $protocol any host $ipsource"
                    set dest_source " permit $protocol host $ipsource any"
                    }
              } else {
                set source_dest "permit ip host $ipsource any"
                set dest_source "permit ip $ipdest any host $ipsource"
              }
            }
      }
  }


 
  
  if { [info exists any_s_d] } {
          ios_config "ip access-list ex CAPTURE-FILTER" "$any_s_d"
          set captureacl "$any_s_d"
    } else {
          ios_config "ip access-list ex CAPTURE-FILTER" "$source_dest" "$dest_source"
          set captureacl "$source_dest \n $dest_source"
    }

  exec "no monitor capture CAPTURE"
  if {[file exists flash:CAPTURE.pcap]} {
      file delete -force -- flash:CAPTURE.pcap
      }
  exec "monitor capture CAPTURE access-list CAPTURE-FILTER"
  exec "monitor capture CAPTURE file location flash:CAPTURE.pcap buffer-size $size size $size"
  exec "monitor capture CAPTURE limit duration $duration packet-len 1600"
  if {$ctype == "control"} {
    exec "monitor capture CAPTURE control-plane both"
  } else { 
    exec "monitor capture CAPTURE interface $sinterface both" 
    }
  
  exec "monitor capture CAPTURE start"
  set total $duration
  for {set i 0 } {$i <= $total} {incr i} {if {$i == 0} {puts "Starting!\n"}; progressbar $i $total $duration; flush stdout ; after 1000; incr duration -1}
  puts ""
  set check [exec "show monitor capture CAPTURE"]
  set stop 0
  while {$stop < 2} {
  if {[regexp {Inactive} $check]} {
      set stop 3;
      } else {puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture CAPTURE"]; incr stop}
  }
  puts "Exporting capture to flash:CAPTURE.pcap"
  exec "monitor capture CAPTURE stop"
  exec "no monitor capture CAPTURE"
  ios_config "no ip access-list extended CAPTURE-FILTER"
  puts "\nDone!\n"
  puts "'show monitor capture file flash:CAPTURE.pcap' to see local wireshark summary"
  finish_statement
}



proc finish_statement {} {
  set allusers [exec "who"]
  set current_user [foreach {line} [split $allusers "\n"] {if {[regexp {\*} $line]} {set foundx $line; set user [regexp -all -inline {\S+} $foundx]}}; lindex $user 4]
  set showip [exec "show tcp br"]
  set current_ip [foreach {line} [split $showip "\n"] {if {[regexp {\.22\s} $line]} {set foundx $line; set ip [regexp -all -inline {\S+} $foundx]}}; lindex $ip 1]
  puts [string repeat * 20]
  puts "Get copy of pcap from flash via \"scp\" or SecureFx"
  set cmdhelper "Windows cmd|powershell \'scp $current_user"
  append cmdhelper "@"
  append cmdhelper [string range $current_ip 0 end-3]
  append cmdhelper ":CAPTURE.pcap . & CAPTURE.pcap'"
  puts $cmdhelper
  
}
 
if {$::argc == 0} {puts "\[HELP\]:\nProvide source and destination {ip|any} with optional interface
    \n Examples:
     \[syntax\] wireshark <protocol> <source_ip:\[port\]> <dest_ip:\[port\]> <capture_type> <duration seconds> <capture size MB>
     wireshark ip any any 
     wireshark ip 192.168.25.2 any
     wireshark ip 192.168.25.2 192.168.30.20 Gi1/0/1
     wireshark ip 192.168.25.2 192.168.30.20 Gi1/0/1 40 10
     wireshark ip 192.168.25.2 192.168.30.20 control 60 30
     
     wireshark tcp any any 
     wireshark tcp 192.168.25.2 any
     wireshark tcp 192.168.25.2 192.168.30.20:443 Gi1/0/1
     wireshark tcp 192.168.25.2:443 192.168.30.20 Gi1/0/1 40 10

     wireshark udp any any 
     wireshark udp 192.168.25.2 any
     wireshark udp 192.168.25.2 192.168.30.20:53 Gi1/0/1
     wireshark udp 192.168.25.2:53 192.168.30.20 Gi1/0/1 40 10\n\n"
} else {
     set get_version [exec "show ver"]
     foreach {line} [split $get_version "\n"]  {
       if {[regexp -nocase "model number" $line]} {
            set found_version [lindex [regexp -all -inline {\S+} $line] 3]
            }
           }
    if {![info exists found_version]} {
      puts "Unable to determine platform. "
      puts -nonewline "Please enter platform number \[example: for csr1000v enter 1000\]:"
      flush stdout
      set found_version [gets stdin {askversion}]
    }
    if {[regexp -nocase {\d\d\d\d*} $found_version]} {
        set device_string "Device version: "
        set version [lindex [regexp -nocase -inline {\d\d\d\d} $found_version] 0]
        append device_string $version
        puts $device_string
        if {$::argc == 3} {main $version [lindex $argv 0] [lindex $argv 1] [lindex $argv 2]} else {main $version [lindex $argv 0] [lindex $argv 1] [lindex $argv 2] [lindex $argv 3] [lindex $argv 4] [lindex $argv 5]}
    }
}

tclquit




