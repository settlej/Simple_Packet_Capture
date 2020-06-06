# Copyright (c) 2020 Joshua Settle <joshuabsettle@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# Simple Cisco Packet Capture.

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

proc clear_screen {} {
    ios_config "line vty 0 15" "international"
    puts "\x1B\x5B\x32\x4A\x1B\x5B\x30\x3B\x30\x48"
    ios_config "line vty 0 15" "no international"
}

proc debugputs {msg} {
    if {$::debug == 1} {
       puts "\[DEBUG\]\: $msg"
    }
}

proc noexec_perform {event} {
    debugputs $event
    $event
}

proc perform {event {iosconfig { }} } {
    debugputs $event
    if {$iosconfig != { }} {
        ios_config $event
    } else {
        exec $event
    }
}

proc gatherinformation_and_begin_capture {version protocol ipsource {ipdest any} {sinterface nothing} {duration {}} {size {}} } {
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
             set foundinterfaces [regexp -all -inline {[A-Za-z-]+\d\/?\d?\/?\d?\/?\d?\d?} [exec "show ip int br"]] 
             #set foundinterfaces [regexp -all -inline {([A-Za-z]+\d\/)+[\d\/]+} [exec "show ip int br"]]
             foreach {a b c d e f g} [join $foundinterfaces ", "] {puts "$a $b $c $d $e $f $g"} 
             set i 0
             puts " "
             while {$i < 1} {
                puts "Which interface to packet capture \[exact syntax needed\]?"
                puts -nonewline "\nSelection: "
                flush stdout
                gets stdin {sinterface}
                if {$sinterface == "exit"} {incr i} else {}
                if {$i > 0} {continue} else {}
                if {[lsearch -exact $foundinterfaces "$sinterface"] == -1} { puts "\nInterface Not found...\n"} else {incr i}
                }
        }
    } else {
    switch -glob $sinterface {
      [c|C]ontrol* {set ctype control}
      default {set ctype Interface}
      }}
 
    if { $duration == {} || $size == {} } {
      if {$duration == {}} {
           puts -nonewline "\nHow long to run capture? <1-300 seconds> \[Default=20\] : "
           flush stdout
           gets stdin {duration}
              if {[string trim $duration] > 0} {
                } else {set duration 20;}
      }
      if {$size == {}} {
          puts -nonewline "\nMax Capture size? <1-50 MB> \[Default=10\] : "
          flush stdout
          gets stdin {size}
          if {[string trim $size] > 0} {} else {set size 10}
          }
      startcapture $version $protocol $ipsource $ipdest $ctype $sinterface $duration $size
    } else {
    startcapture $version $protocol $ipsource $ipdest $ctype $sinterface $duration $size
    }
}

proc versionsearch {version protocol ipsource ipdest ctype sinterface duration size} {
    switch -glob $version {
       9*   {capture_commands9000 $protocol $ipsource $ipdest $ctype $sinterface $duration $size}
       44*  {capture_commands4400 $protocol $ipsource $ipdest $ctype $sinterface $duration $size}
       1004 {capture_commands4400 $protocol $ipsource $ipdest $ctype $sinterface $duration $size}
       45*  {capture_commands4500 $protocol $ipsource $ipdest $ctype $sinterface $duration $size}
       38*  {capture_commands3800 $protocol $ipsource $ipdest $ctype $sinterface $duration $size}
       3*   {capture_commands3000 $protocol $ipsource $ipdest $ctype $sinterface $duration $size}
       100* {capture_commands1000 $protocol $ipsource $ipdest $ctype $sinterface $duration $size}
       default {puts "Unsupported Version!"}
    }
}


proc startcapture {version protocol ipsource ipdest ctype sinterface duration size} {
      puts "Capture Overview\n"
      puts [string repeat - 37]
      if {$sinterface != "nothing" || $sinterface == "control"} {
        puts "Capture: $sinterface \nDuration: $duration Sec \nFile Size: $size MB"
      } else {
        puts "Capture Type: Control-Plane \nDuration: $duration Sec \nFile Size: $size MB"
      }
      if { $ipsource == "any" && $ipdest == "any" } {
        puts "Capture ACL: $protocol any any"
      } else {
          puts "Capture ACL: $protocol $ipsource $ipdest 
             $protocol $ipdest $ipsource"
      }
      puts "Capture location: flash:CAPTURE.pcap"
      puts [string repeat - 37]
      puts ""
      if {$protocol == "ip" && $ipsource == "any" && $ipdest == "any"} {
          puts "****WARNING!**** Using \"ip any any\" may create stress on CPU, if possible try to limit to tcp/udp/eigrp/ospf/icmp.
                 Also make sure time duration is at a reasonable time if monitoring high load interface."
      }
      if {[expr $duration > 300]} {
          puts "***TERMINIATING! Duration is greater than 300 sec ***"; return
      }
      if [catch {exec "dir flash: | i free"} result] {
          set result [exec "dir bootflash: | i free"]
      } 
      set flashsize $result   
      set bytesizefree [lindex [regexp -all -inline {\S+} [lindex [split $flashsize {(}] 1]] 0]
      set bytesizefree "${bytesizefree}.0"
      if {[expr [expr $bytesizefree - $size] < 10000]} {
         puts "***TERMINATING! Not enought Free Space Available*** "; return
      }
      if {[expr $size > 99]} {
         puts "***TERMINATING! Size is greater than 99 MB ***"; return
      }
      if {[expr $duration > 120]} {
         puts "***WARNING! Greater than 120 sec capture, use with Caution ***"
      }
      if {[expr $size > 70]} {
         puts "***WARNING! File size greater than 70 MB will be saved to flash make sure flash has enough room!***"
      }
      puts ""
      puts -nonewline "Start? \[yes\|no\]: "
      flush stdout
      gets stdin {start}
      switch -glob $start {
        y* { versionsearch $version $protocol $ipsource $ipdest $ctype $sinterface $duration $size}
        default { puts "\nCanceling!" }
    }
}
  
proc acl_generator {protocol ipsource ipdest} {
    if { $ipsource == "any" && $ipdest == "any" } {
          set any_s_d " permit $protocol any any"
    } else {
          if { $ipsource != "any" && $ipdest != "any" } {
              if { $protocol == "tcp" || $protocol == "udp" } {
                  if { [regexp {\:} $ipsource] && [regexp {\:} $ipdest] } {
                      set sourcesplit [ split $ipsource {:} ]
                      set destsplit [ split $ipdest {:} ]
                      if {[regexp -nocase {any} $ipdest] || [regexp -nocase {any} $ipsource]} {
                          if {[regexp -nocase {any} $ipdest]} {
                              set source_dest "permit $protocol host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] [lindex $destsplit 0] eq [lindex $destsplit 1]"
                              set dest_source "permit $protocol [lindex $destsplit 0] eq [lindex $destsplit 1] host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                          } else {
                              set source_dest "permit $protocol [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] host [lindex $destsplit 0] eq [lindex $destsplit 1]"
                              set dest_source "permit $protocol host [lindex $destsplit 0] eq [lindex $destsplit 1] [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                          }
                      } else {
                              set source_dest "permit $protocol host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] host [lindex $destsplit 0] eq [lindex $destsplit 1]"
                              set dest_source "permit $protocol host [lindex $destsplit 0] eq [lindex $destsplit 1] host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                             }
                      
                        
                  } else { 
                      if { [regexp {\:} $ipsource] || [regexp {\:} $ipdest] } {
                          if { [regexp {\:} $ipsource] } {
                               set sourcesplit [ split $ipsource {:} ]
                               if {[regexp -nocase {any} $ipsource] } {
                                      if {[regexp -nocase {any} $ipsource] } {
                                        set source_dest "permit $protocol [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] host $ipdest"
                                        set dest_source "permit $protocol host $ipdest [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                                      } else {
                                        set source_dest "permit $protocol host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] $ipdest"
                                        set dest_source "permit $protocol $ipdest host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                                      }
                               } else {
                                  # set destsplit [ split $ipdest {:} ]
                                   if {[regexp -nocase {any} $ipdest] } {
                                      set source_dest "permit $protocol $ipdest host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                                      set dest_source "permit $protocol host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] $ipdest"
                                   } else {
                                      set source_dest "permit $protocol host $ipdest host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                                      set dest_source "permit $protocol host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] host $ipdest"
                                   }
                               }
                          } else {
                                  set destsplit [ split $ipdest {:} ]
                                  if {[regexp -nocase {any} $ipdest] } {
                                           set source_dest "permit $protocol [lindex $destsplit 0] eq [lindex $destsplit 1] host $ipsource"
                                           set dest_source "permit $protocol host $ipsource [lindex $destsplit 0] eq [lindex $destsplit 1]"
                                  } else {
                                           set source_dest "permit $protocol host [lindex $destsplit 0] eq [lindex $destsplit 1] host $ipsource"
                                           set dest_source "permit $protocol host $ipsource host [lindex $destsplit 0] eq [lindex $destsplit 1]"
                                  }
                          }
                      } else {
                              set source_dest "permit $protocol host $ipsource host $ipdest"
                              set dest_source "permit $protocol host $ipdest host $ipsource"
                      }
                  }
              } else {
                set source_dest "permit ip host $ipsource host $ipdest"
                set dest_source "permit ip host $ipdest host $ipsource"
                }
        } else {
              if { $ipsource == "any" && $ipdest != "any" } {
                  if { $protocol == "tcp" || $protocol == "udp" } {
                      if { [regexp {\:} $ipdest ] } {
                           set destsplit [ split $ipdest {:} ]
                           if {[regexp -nocase {any} $ipdest]} {
                              set source_dest "permit $protocol $ipsource [lindex $destsplit 0] eq [lindex $destsplit 1]"
                              set dest_source "permit $protocol [lindex $destsplit 0] eq [lindex $destsplit 1] $ipsource"
                           } else {
                              set source_dest "permit $protocol $ipsource host [lindex $destsplit 0] eq [lindex $destsplit 1]"
                              set dest_source "permit $protocol host [lindex $destsplit 0] eq [lindex $destsplit 1] $ipsource"
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
                      if { [regexp {\:} $ipsource ] } {
                          set sourcesplit [ split $ipsource {:} ]
                          if {[regexp -nocase {any} $ipsource]} {
                              set source_dest "permit $protocol [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] $ipdest"
                              set dest_source "permit $protocol $ipdest [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
                          } else {
                              set source_dest "permit $protocol host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1] $ipdest"
                              set dest_source "permit $protocol $ipdest host [lindex $sourcesplit 0] eq [lindex $sourcesplit 1]"
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
      return $any_s_d
  } else {
      return "$source_dest:$dest_source"
  }
}

proc capture_commands3000 { protocol ipsource ipdest ctype sinterface duration size} {
    perform "monitor capture point stop all"
    perform "no access-list 199" iosconfig
    set aclresults [split [acl_generator $protocol $ipsource $ipdest] ":"]
    if {[llength $aclresults] == 1} {
      set any_s_d [lindex $aclresults 0]
    } else {
      set source_dest [lindex $aclresults 0]
      set dest_source [lindex $aclresults 1]
    }
    if {[info exists any_s_d]} {
      perform "access-list 199 $any_s_d" iosconfig
    } else {
      perform "access-list 199 $source_dest" iosconfig
      perform "access-list 199 $dest_source" iosconfig
    }
    perform "monitor capture buffer BUFF linear"
    perform "monitor capture buffer BUFF filter access-list 199"
    set buffsize [expr $size * 1000]
    debugputs "\(INFO\) Buffer-size $buffsize KB"
    perform "monitor capture buffer BUFF size $buffsize"
    # <256-102400 Kbytes>
    perform "monitor capture buffer BUFF limit duration $duration"
    # <1-2000 sec>
    debugputs "\(INFO\) Max MTU capture set to 172"
    perform "monitor capture buffer BUFF max-size 172"
    if {$ctype == "control"} {
       perform "monitor capture point ip process-switched POINT both"
    } else { 
      perform "monitor capture point ip cef POINT $sinterface both" 
      }
    perform "monitor capture point associate POINT BUFF"
    # <wait> show monitor capture buffer BUFF parameters
    # <wait> or show monitor capture buffer BUFF dump
    perform "monitor capture point start POINT"
    set total $duration
    for {set i 0 } {$i <= $total} {incr i} {if {$i == 0} {puts "Starting!\n"}; progressbar $i $total $duration; flush stdout ; after 1000; incr duration -1}
    puts ""
    debugputs "\(INFO\) Checking capture status"
    set check [perform "show monitor capture point POINT"]
    set stop 0
    while {$stop < 2} {
    if {[regexp {Inactive} $check]} {
        set stop 3;
        } else {puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture point POINT"]; incr stop}
    }
    perform "monitor capture point stop POINT"
    debugputs "\(INFO\) Exporting capture to flash:CAPTURE.pcap"
    perform "monitor capture buffer BUFF export flash:CAPTURE.pcap"
    if {$ctype == "control"} {
       perform "no monitor capture point ip process-switched POINT both"
    } else {
       perform "no monitor capture point ip cef POINT $sinterface both"
    }
    perform "no monitor capture buffer BUFF"
    perform "no access-list 199" iosconfig
    puts "\nDone!\n"
    finish_statement
} 
      


proc find_dest_next_hop_interface {destlookupnexthop} {
    set lookup [exec "show ip cef $destlookupnexthop detail | i nexthop"]
    set nexthopinterface [lindex [split $lookup ] end]
    if {[regexp {[V|v]lan} $nexthopinterface]} {
        set arpaddr [lindex [split $lookup ] end-1]
        set mac [lindex [regexp -inline -all {\S+} [exec "sho ip arp | i $arpaddr"] ] 3]
        set vlannum [regexp -inline -all {\d+} $nexthopinterface]
        set macoutput [exec "show mac add vlan $vlannum | i $mac"]
        set interface [lindex [regexp -inline -all {\S+} $macoutput ] end]
        return $interface
    } else {
        return $nexthopinterface
    }
}
    
proc capture_commands4500 { protocol ipsource ipdest ctype sinterface duration size} {
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
	if {[regexp {any} $ipsource] && [regexp {any} $ipdest]} {
          puts "\n"
          puts "***FAILURE*** Both IP source and IP destination are \"any any\", needs to have single SOURCE IP. \n\n\[ENDING PROGRAM\]"
          perform "no monitor capture CAPTURE"
          perform "no ip access-list extended CAPTURE-FILTER" iosconfig
          perform "no class-map CAPTURE_CLASS_MAP" iosconfig
		  return
       }

    if {$ctype != "control"} {
        if {[regexp {any} $ipdest]} {
          set destlookupnexthop "0.0.0.0/0"
        } else {
          if {[regexp {:} $ipdest]} {
            set destlookupnexthop [lindex [split $ipdest {:}] 0]
          } else {
          set destlookupnexthop $ipdest
          }
        }
        set interfaceresult [find_dest_next_hop_interface $destlookupnexthop]
        if {$interfaceresult != ""} { 
            set additionalinterface $interfaceresult
            debugputs "\(INFO\) Found Reverse Interface: $additionalinterface"
        } else {
            puts "\n"
            puts "***FAILURE*** Failed to find Reverse Interface!!"
			puts "\n"
			puts "\[ENDING PROGRAM\]"
            return
        }
    }
  
    set aclresults [split [acl_generator $protocol $ipsource $ipdest] ":"]
    if {[llength $aclresults] == 1} {
      set any_s_d [lindex $aclresults 0]
    } else {
      set source_dest [lindex $aclresults 0]
      set dest_source [lindex $aclresults 1]
    }
    if { [info exists any_s_d] } {
            ios_config "ip access-list ex CAPTURE-FILTER" "$any_s_d"
            debugputs "ip access-list ex CAPTURE-FILTER $any_s_d"
            set captureacl "$any_s_d"
        } else {
            ios_config "ip access-list ex CAPTURE-FILTER" "$source_dest" "$dest_source"
            debugputs "ip access-list ex CAPTURE-FILTER"
            debugputs "  $source_dest"
            debugputs "  $dest_source"
            set captureacl "$source_dest \n $dest_source"
        }
  
    perform "no monitor capture CAPTURE"
	perform "no class-map CAPTURE_CLASS_MAP" iosconfig
    if {[file exists bootflash:CAPTURE.pcap]} {
        file delete -force -- bootflash:CAPTURE.pcap
        }
    ios_config "class-map CAPTURE_CLASS_MAP" "match access-group name CAPTURE-FILTER"
    debugputs "class-map CAPTURE_CLASS_MAP"
    debugputs "    match access-group name CAPTURE-FILTER"
    set buffersize [expr $size + 10]
    debugputs "\(INFO\) Buffersize additon 10 + $size = $buffersize MB"
    if {$ctype == "control"} {
        noexec_perform "monitor capture CAPTURE class-map CAPTURE_CLASS_MAP"
        noexec_perform "monitor capture CAPTURE file location bootflash:CAPTURE.pcap buffer-size $buffersize size $size control-plane both "
        noexec_perform "monitor capture CAPTURE limit duration $duration packet-len 172"
    } else { 
          noexec_perform "monitor capture CAPTURE class-map CAPTURE_CLASS_MAP"
          noexec_perform "monitor capture CAPTURE limit packet-len 172"
          noexec_perform "monitor capture CAPTURE interface $sinterface both file location bootflash:CAPTURE.pcap buffer-size $buffersize size $size limit duration $duration"
      if {[info exists additionalinterface]} {
          noexec_perform "monitor capture CAPTURE interface $additionalinterface in"
        }
    }

    noexec_perform "monitor capture CAPTURE start"
    set total $duration
    for {set i 0 } {$i <= $total} {incr i} {if {$i == 0} {puts "Starting!\n"}; progressbar $i $total $duration; flush stdout ; after 1000; incr duration -1}
    puts ""
    set check [perform "show monitor capture CAPTURE"]
    set stop 0
    while {$stop < 2} {
    if {[regexp {Inactive} $check]} {
        set stop 3;
        } else {puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture CAPTURE"]; incr stop}
    }
    perform "monitor capture CAPTURE stop"
    after 1000
    perform "no monitor capture CAPTURE"
    perform "no monitor capture CAPTURE"
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    perform "no class-map CAPTURE_CLASS_MAP" iosconfig
    puts "\nDone!\n"
    finish_statement
}


proc capture_commands9000 { protocol ipsource ipdest ctype sinterface duration size} {
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    set aclresults [split [acl_generator $protocol $ipsource $ipdest] ":"]
    if {[llength $aclresults] == 1} {
      set any_s_d [lindex $aclresults 0]
    } else {
      set source_dest [lindex $aclresults 0]
      set dest_source [lindex $aclresults 1]
    }
    if { [info exists any_s_d] } {
            ios_config "ip access-list ex CAPTURE-FILTER" "$any_s_d"
            debugputs "ip access-list ex CAPTURE-FILTER $any_s_d"
            set captureacl "$any_s_d"
        } else {
            ios_config "ip access-list ex CAPTURE-FILTER" "$source_dest" "$dest_source"
            debugputs "ip access-list ex CAPTURE-FILTER"
            debugputs "  $source_dest"
            debugputs "  $dest_source"
            set captureacl "$source_dest \n $dest_source"
        }

    perform "no monitor capture CAPTURE"
	puts ""
    if {[file exists flash:CAPTURE.pcap]} {
        file delete -force -- flash:CAPTURE.pcap
        }
    set buffsize [expr $size * 1000]
    noexec_perform "monitor capture CAPTURE access-list CAPTURE-FILTER"
    noexec_perform "monitor capture CAPTURE file location flash:CAPTURE.pcap buffer-size $size size $size"
    noexec_perform "monitor capture CAPTURE limit duration $duration packet-len 172"
    if {$ctype == "control"} {
      noexec_perform "monitor capture CAPTURE control-plane both"
    } else { 
      noexec_perform "monitor capture CAPTURE interface $sinterface both"
      }
    noexec_perform "monitor capture CAPTURE start"
    set total $duration
    for {set i 0 } {$i <= $total} {incr i} {if {$i == 0} {puts "Starting!\n"}; progressbar $i $total $duration; flush stdout ; after 1000; incr duration -1}
    puts ""
    set check [perform "show monitor capture CAPTURE"]
    set stop 0
    while {$stop < 2} {
    if {[regexp {Inactive} $check]} {
        set stop 3;
        } else {puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture CAPTURE"]; incr stop}
    }
    puts "Exporting capture to flash:CAPTURE.pcap"
    perform "monitor capture CAPTURE stop"
    perform "no monitor capture CAPTURE"
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    puts "\nDone!\n"
    puts "'show monitor capture file flash:CAPTURE.pcap' to see local wireshark summary"
    finish_statement
}

proc capture_commands3800 { protocol ipsource ipdest ctype sinterface duration size} {
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    set aclresults [split [acl_generator $protocol $ipsource $ipdest] ":"]
    if {[llength $aclresults] == 1} {
      set any_s_d [lindex $aclresults 0]
    } else {
      set source_dest [lindex $aclresults 0]
      set dest_source [lindex $aclresults 1]
    }
    if { [info exists any_s_d] } {
            ios_config "ip access-list ex CAPTURE-FILTER" "$any_s_d"
            debugputs "ip access-list ex CAPTURE-FILTER  $any_s_d"
            set captureacl "$any_s_d"
        } else {
            ios_config "ip access-list ex CAPTURE-FILTER" "$source_dest" "$dest_source"
            debugputs "ip access-list ex CAPTURE-FILTER"
            debugputs "  $source_dest"
            debugputs "  $dest_source"
            set captureacl "$source_dest \n $dest_source"
        }

    perform "no monitor capture CAPTURE"
    perform "no class-map CAPTURE_CLASS_MAP" iosconfig

    if {[file exists flash:CAPTURE.pcap]} {
        file delete -force -- flash:CAPTURE.pcap
        }
    ios_config "class-map CAPTURE_CLASS_MAP" "match access-group name CAPTURE-FILTER"
    debugputs "class-map CAPTURE_CLASS_MAP"
	debugputs "    match access-group name CAPTURE-FILTER"
    if {$ctype == "control"} {
      noexec_perform "monitor capture CAPTURE class-map CAPTURE_CLASS_MAP "
      noexec_perform "monitor capture CAPTURE limit packet-len 172"
      noexec_perform "monitor capture CAPTURE file location flash:CAPTURE.pcap buffer-size $size limit duration $duration"
      noexec_perform "monitor capture CAPTURE control-plane both "
  
    } else { 
          noexec_perform "monitor capture CAPTURE class-map CAPTURE_CLASS_MAP"
          noexec_perform "monitor capture CAPTURE limit packet-len 172"
          noexec_perform "monitor capture CAPTURE file location flash:CAPTURE.pcap buffer-size $size limit duration $duration"
          noexec_perform "monitor capture CAPTURE interface $sinterface both "
      }
    
    noexec_perform "monitor capture CAPTURE start"
    set total $duration
    for {set i 0 } {$i <= $total} {incr i} {if {$i == 0} {puts "\n"}; progressbar $i $total $duration; flush stdout ; after 1000; incr duration -1}
    puts ""
    set check [perform "show monitor capture CAPTURE"]
    set stop 0
    while {$stop < 2} {
    if {[regexp {Inactive} $check]} {
        set stop 3;
        } else {puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture CAPTURE"]; incr stop}
    }
    perform "monitor capture CAPTURE stop"
    perform "no monitor capture CAPTURE"
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    perform "class-map CAPTURE_CLASS_MAP" iosconfig
    puts "\nDone!\n"
    finish_statement
}

proc capture_commands4400 { protocol ipsource ipdest ctype sinterface duration size} {
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    set aclresults [split [acl_generator $protocol $ipsource $ipdest] ":"]
    if {[llength $aclresults] == 1} {
      set any_s_d [lindex $aclresults 0]
    } else {
      set source_dest [lindex $aclresults 0]
      set dest_source [lindex $aclresults 1]
    }
    if { [info exists any_s_d] } {
              ios_config "ip access-list ex CAPTURE-FILTER" "$any_s_d"
              debugputs "ip access-list ex CAPTURE-FILTER $any_s_d"
              set captureacl "$any_s_d"
        } else {
            ios_config "ip access-list ex CAPTURE-FILTER" "$source_dest" "$dest_source"
            debugputs "ip access-list ex CAPTURE-FILTER"
            debugputs "  $source_dest"
            debugputs "  $dest_source"
              set captureacl "$source_dest \n $dest_source"
        }
    
    perform "no monitor capture CAPTURE"
	puts ""

    if {[file exists flash:CAPTURE.pcap]} {
        file delete -force -- flash:CAPTURE.pcap
        }
  
    if {$ctype == "control"} {
      noexec_perform "monitor capture CAPTURE limit packet-len 172 duration $duration" 
      noexec_perform "monitor capture CAPTURE access-list CAPTURE-FILTER buffer size $size control-plane both"
  
    } else { 
      noexec_perform "monitor capture CAPTURE limit packet-len 172 duration $duration "
      noexec_perform "monitor capture CAPTURE access-list CAPTURE-FILTER buffer size $size interface $sinterface both"
      }
    noexec_perform "monitor capture CAPTURE start"
    set total $duration
    for {set i 0 } {$i <= $total} {incr i} {if {$i == 0} {puts "Starting!\n"}; progressbar $i $total $duration; flush stdout ; after 1000; incr duration -1}
    puts ""
    set check [perform "show monitor capture CAPTURE"]
    set stop 0
    while {$stop < 2} {
    if {[regexp {Inactive} $check]} {
        set stop 3;
        } else {puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture CAPTURE"]; incr stop}
    }
    debugputs "\(INFO\) Exporting capture to bootflash:CAPTURE.pcap"
    perform "monitor capture CAPTURE stop"
    perform "monitor capture CAPTURE export bootflash:CAPTURE.pcap"
    perform "no monitor capture CAPTURE"
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    puts "\nDone!\n"
    finish_statement
}

proc capture_commands1000 { protocol ipsource ipdest ctype sinterface duration size} {
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    set aclresults [split [acl_generator $protocol $ipsource $ipdest] ":"]
    if {[llength $aclresults] == 1} {
      set any_s_d [lindex $aclresults 0]
    } else {
      set source_dest [lindex $aclresults 0]
      set dest_source [lindex $aclresults 1]
    }
    if { [info exists any_s_d] } {
            ios_config "ip access-list ex CAPTURE-FILTER" "$any_s_d"
            debugputs "ip access-list ex CAPTURE-FILTER $any_s_d"
            set captureacl "$any_s_d"
        } else {
            ios_config "ip access-list ex CAPTURE-FILTER" "$source_dest" "$dest_source"
            debugputs "ip access-list ex CAPTURE-FILTER"
            debugputs "  $source_dest"
            debugputs "  $dest_source"
            set captureacl "$source_dest \n $dest_source"
        }
  
    perform "no monitor capture CAPTURE"
    if {[file exists flash:CAPTURE.pcap]} {
        file delete -force -- flash:CAPTURE.pcap
        }
    noexec_perform "monitor capture CAPTURE limit packet-len 172"
    noexec_perform "monitor capture CAPTURE access-list CAPTURE-FILTER"
    noexec_perform "monitor capture CAPTURE buffer size $size"
    noexec_perform "monitor capture CAPTURE limit duration $duration"
  
    if {$ctype == "control"} {
      noexec_perform "monitor capture CAPTURE control-plane both"
    } else { 
      noexec_perform "monitor capture CAPTURE interface $sinterface both"
      }
    noexec_perform "monitor capture CAPTURE start"
    set total $duration
    for {set i 0 } {$i <= $total} {incr i} {if {$i == 0} {puts "Starting!\n"}; progressbar $i $total $duration; flush stdout ; after 1000; incr duration -1}
    puts ""
    set check [perform "show monitor capture CAPTURE"]
    set stop 0
    while {$stop < 2} {
    if {[regexp {Inactive} $check]} {
        set stop 3;
        } else {puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture CAPTURE"]; incr stop}
    }
    debugputs "\(INFO\)Exporting capture to flash:CAPTURE.pcap"
    perform "monitor capture CAPTURE stop"
    perform "monitor capture CAPTURE export flash:CAPTURE.pcap"
    perform "no monitor capture CAPTURE"
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    puts "\nDone!\n"
    finish_statement
}

proc finish_statement {} {
    set allusers [exec "who"]
    set who_user [foreach {line} [split $allusers "\n"] {if {[regexp {\*} $line]} { set foundx $line; set user [regexp -all -inline {\S+} $foundx]}}; lindex $user 4]
    set allusers [exec "show aaa sessions | i $who_user"]
    set current_user [string trim [lindex [split $allusers ":"] 1]]
    set temp [string trim [lindex [split $allusers ":"] 1]]
    if {[string first "\n" $temp] == -1} {
        set current_user $temp
    } else {
    set current_user [string trim [string range $temp 0 [string first "\n" $temp]]]
    }
    set showip [exec "show tcp br"]
    set current_ip [foreach {line} [split $showip "\n"] {
        if {[regexp {\.22\s} $line]} {
            set foundx $line; set ip [regexp -all -inline {\S+} $foundx]}
            }; lindex $ip 1]
    puts [string repeat * 20]
    puts "Get copy of pcap from flash via \"scp\" or SecureFx"
    set cmdhelper "Windows CMD \'scp $current_user"
    append cmdhelper "@"
    append cmdhelper [string range $current_ip 0 end-3]
    append cmdhelper ":CAPTURE.pcap . & .\\CAPTURE.pcap'"
    puts $cmdhelper
    set cmdhelper "Windows Powershell \'scp $current_user"
    append cmdhelper "@"
    append cmdhelper [string range $current_ip 0 end-3]
    append cmdhelper ":CAPTURE.pcap . ; .\\CAPTURE.pcap'"
    puts $cmdhelper

}


proc cli_show_filters { version } {
    switch -glob $version {
        9*   {flash_devices}
        45*  {bootflash_devices}
        38*  {flash_devices}
        3*   {flash_devices}
        1004 {puts "CLI File Display Unsupported. Must SCP to local Computer!"}
        100* {flash_devices}
        default {puts "CLI File Display Unsupported. Must SCP to local Computer!"}
    }
}

proc flash_devices {} {
   puts "
   
    #Basic filters
       show monitor capture file bootflash:CAPTURE.pcap brief
       show monitor capture file flash:CAPTURE.pcap display-filter icmp
       show monitor capture file flash:CAPTURE.pcap display-filter tcp 
       show monitor capture file flash:CAPTURE.pcap display-filter udp 
    
    #Routing protocols
       show monitor capture file flash:CAPTURE.pcap display-filter \"eigrp || ospf || tcp.port == 179\"
    
    #Web traffic
       show monitor capture file flash:CAPTURE.pcap display-filter \"tcp.port == 80 || tcp.port == 443\"
    
    #DHCP
       show monitor capture file flash:CAPTURE.pcap display-filter dhcp
    
    #DNS
       show monitor capture file flash:CAPTURE.pcap display-filter \"udp.port == 53\"
    
    #Traffic to or from IP
       \[First example does src \'and\' dst for 1.1.1.1 use ip.addr\]
       show monitor capture file flash:CAPTURE.pcap display-filter \"ip.addr == 1.1.1.1\"
       show monitor capture file flash:CAPTURE.pcap display-filter \"ip.src_host == 1.1.1.1\"
       show monitor capture file flash:CAPTURE.pcap display-filter \"ip.dst_host == 1.1.1.1\"
    
    #TCP Rest Flag
       Show monitor capture file flash:CAPTURE.pcap display-filter \"tcp.flags.reset == 1\"
    
   "
}


proc bootflash_devices {} {
   puts "
   
    #Basic filters
       show monitor capture file bootflash:CAPTURE.pcap brief
       show monitor capture file bootflash:CAPTURE.pcap display-filter icmp
       show monitor capture file bootflash:CAPTURE.pcap display-filter tcp 
       show monitor capture file bootflash:CAPTURE.pcap display-filter udp 
    
    #Routing protocols
       show monitor capture file bootflash:CAPTURE.pcap display-filter \"eigrp || ospf || tcp.port == 179\"
    
    #Web traffic
       show monitor capture file bootflash:CAPTURE.pcap display-filter \"tcp.port == 80 || tcp.port == 443\"
    
    #DHCP
       show monitor capture file bootflash:CAPTURE.pcap display-filter dhcp
    
    #DNS
       show monitor capture file bootflash:CAPTURE.pcap display-filter \"udp.port == 53\"
    
    #Traffic to or from IP
       \[First example does src \'and\' dst for 1.1.1.1 use ip.addr\]
       show monitor capture file bootflash:CAPTURE.pcap display-filter \"ip.addr == 1.1.1.1\"
       show monitor capture file bootflash:CAPTURE.pcap display-filter \"ip.src_host == 1.1.1.1\"
       show monitor capture file bootflash:CAPTURE.pcap display-filter \"ip.dst_host == 1.1.1.1\"
    
    #TCP Rest Flag
       Show monitor capture file bootflash:CAPTURE.pcap display-filter \"tcp.flags.reset == 1\"
    
   "
}

proc displayhelp {} {
    puts "\n\[HELP\]:\nProvide source and destination {ip|any} with optional interface
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
         wireshark udp 192.168.25.2:53 192.168.30.20 Gi1/0/1 40 10
    
         ***If you want display pcap on cli examples type:
         wireshark filter

         ***If you want to see commands sent to IOS:
         wireshark --debug <protocol> <source_ip:\[port\]> <dest_ip:\[port\]> <capture_type> <duration seconds> <capture size MB>
       
       "
}

proc getversion {} {
    set get_version [exec "show ver"]
    foreach {line} [split $get_version "\n"]  {
        if {[regexp -nocase "model number" $line]} {
            set found_version [lindex [regexp -all -inline {\S+} $line] 3]
        }
    }
    if {![info exists found_version]} {
       foreach {line} [split $get_version "\n"]  {
            if {[regexp {(CSR1000V)|(C45\d\d)|(ASR100\d)|(ISR44\d\d)} $line]} {
               set found_version [lindex [regexp -all -inline {\S+} $line] 1]
            } 
        }
    }
    if {![info exists found_version]} {
        puts "Unable to determine platform. "
        return 0
    }
    
    if {[regexp {\d\d\d\d*} $found_version]} {
        set version [lindex [regexp -inline {\d\d\d\d} $found_version] 0]
        puts "Device version: $version"
        return "$version"
    } else {
        puts "Unable to determine platform. "
        return 0
    }
}


proc main {} {
    if {$::argc == 0} {
        displayhelp; return
        }
    set version [getversion]
    if {$::argc == 1 && [lindex $::argv 0] == "filter"} {
            cli_show_filters $version; return 
        }
    if {[lindex $::argv 0] == "--debug"} {
        if {[expr $::argc < 4]} {
            puts "\nMissing one of the required arguments \<protocol\> \<sourceip|any\> \<destip|any\>"; return
        } else {
            clear_screen
            global debug; set debug 1; puts "\[Debugging mode\]"
            if {$version == 0} { return }
            if {[expr $::argc == 4]} {
                gatherinformation_and_begin_capture $version [lindex $::argv 1] [lindex $::argv 2] [lindex $::argv 3]
            } else {
                gatherinformation_and_begin_capture $version [lindex $::argv 1] [lindex $::argv 2] [lindex $::argv 3] [lindex $::argv 4] [lindex $::argv 5] [lindex $::argv 6]
            }
        }
        return
    } else {
        if {$::argc < 3} {
		    puts "\nMissing one of the required arguments \<protocol\> \<sourceip|any\> \<destip|any\>"; return
        } else {
            global debug; set debug 0 
            clear_screen
            if {$version == 0} { return }
            if {[expr $::argc == 3]} {
                gatherinformation_and_begin_capture $version [lindex $::argv 0] [lindex $::argv 1] [lindex $::argv 2]
            } else {
                gatherinformation_and_begin_capture $version [lindex $::argv 0] [lindex $::argv 1] [lindex $::argv 2] [lindex $::argv 3] [lindex $::argv 4] [lindex $::argv 5]
            }
        }
    }    
}
        
main 

tclquit
