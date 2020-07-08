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


###############################################################################
#
# Created to simplify packet capture program on Cisco devices that support
# native packet capture.  Many Cisco platforms reqiure different commands 
# to start packet capture.  There was also the issue of requiring 
# multiple commands up to 14 different commands to start capturing. This is
# depending on how grainularity of capture.  This project was created to simplify
# said operations in a "common" user friendly interface on any supported
# platform.  Capture can happen in just 2 user inputs (initial decleration and 
# approving capture confirmation)
#
###############################################################################


# prints progressbar to count down time until program is done captureing
# progress is based on the $duration variable. 
proc progressbar {cur tot} {
    # if you don't want to redraw all the time, uncomment and change ferquency
    #if {$cur % ($tot/300)} { return }
    # set to total width of progress bar
    set total 76
    set half [expr {$total/2}]
    set percent [expr {100.*$cur/$tot}]
    set val (\ [format "%6.2f%%" $percent]\ )
    # '\b' is backspace in tcl on the terminal to continue using same terminal line for progress bar progression, by placing the cursor to the beginning
    set bar "|[string repeat = [expr {round($percent*$total/100)}]][string repeat { } [expr {$total-round($percent*$total/100)}]]|[string repeat \b 110]"
    set bar "$val [string range $bar 0 $half][string range $bar [expr {$half+[string length $val]-1}] end]"
    puts -nonewline stderr $bar
}

# function to clear screen but only displaying capture section
proc clear_screen {} {
    # requires enabling 8 bit support which is not on by default in vty lines
    ios_config "line vty 0 15" "international"
    puts "\x1B\x5B\x32\x4A\x1B\x5B\x30\x3B\x30\x48"
    # remove once cleared
    ios_config "line vty 0 15" "no international"
}

# function to display string only when debug variable set to "1"
proc debugputs {msg} {
    if {$::debug == 1} {
       puts "\[DEBUG\]\: $msg"
    }
}

# function to send to debug checker for display or not then execute IOS command without using "exec" tcl command
# Some IOS commands requried confirmation and "exec" puts command in blocking state until done, which is not
# useful when needing to see output on stdout.
proc noexec_perform {event} {
    debugputs $event
    $event
}

# function to send to debug checker for display or not then execute IOS command using "exec" tcl command
# exec allows for output capture to variables.
proc perform {event {iosconfig { }} } {
    debugputs $event
    if {$iosconfig != { }} {
        ios_config $event
    } else {
        exec $event
    }
}

proc getlargest_interface {interfacelist} {
    # declaring starting numbers
    set currentmax 0
    set largestinterface ""
    foreach {interface} $interfacelist {
        # if interface is longer than previous largest known interface, declare new interface as largest
        if {[expr [string bytelength $interface] > $currentmax]} {
            set largestinterface $interface
            set currentmax [string bytelength $interface]
        }
    }
    return $currentmax
}

# function to parse and search inital capture declaration, if any missing info request via question dialog
proc gatherinformation_and_begin_capture {version protocol ipsource ipdest {sinterface nothing} {duration {}} {size {}} {mtu 172}} {
    if {$sinterface == "nothing"} {
        # If interface not provide at start ask for interface or control-plane capture
        puts "\nCapture Type:\n  1.\) Interface \[default\]\n  2.\) Control-Plane"
        # puts nonewline will not include "\n" at the end but you need to do a "flush" to empty the stdout channel for print on screen
        puts -nonewline "\nSelection: "
        flush stdout
        # Ask user input with "gets", it will look at the standard-in channel
        # depending if type is interface vs control-plane capture will determint capture commands
        gets stdin {ctype}
        switch $ctype {
            "1" {set ctype "Interface"} 
            "2" {set ctype "control"} 
            default {set ctype "Interface"}}
        if {$ctype == "Interface"} { 
             puts "\nAvailable Interfaces:"
             # Grab interfaces from "show ip interface brief" and using regex to grap interface names into a list
             set foundinterfaces [regexp -all -inline {[A-Za-z-]+\d\/?\d?\/?\d?\/?\d?\d?} [exec "show ip int br"]] 
             # find longest interface name for padding on display, used in format below
             set largestinterfacesize [expr [getlargest_interface $foundinterfaces] + 2]
             foreach {a b c d e} [join $foundinterfaces " "] {
                 # add padding for clean looking screen display
                 set a [format {%-*s} $largestinterfacesize  $a]
                 set b [format {%-*s} $largestinterfacesize  $b]
                 set c [format {%-*s} $largestinterfacesize  $c]
                 set d [format {%-*s} $largestinterfacesize  $d]
                 set e [format {%-*s} $largestinterfacesize  $e]
                 # creates 5 column print based on padding
                 puts "$a $b $c $d $e"} 
             set i 0
             puts " "
             while {$i < 1} {
                puts "Which interface to packet capture \[exact name needed\]?"
                puts -nonewline "\nSelection: "
                flush stdout
                gets stdin {sinterface}
                if {$sinterface == "exit"} {incr i} else {}
                if {$i > 0} {continue} else {}
                # simple error checking via searching interface list with its exact name from user input
                if {[lsearch -exact $foundinterfaces "$sinterface"] == -1} { puts "\nInterface Not found...\n"} else {incr i}
                }
        }
    } else {
          # if original argument includes a $sinterface based on what was defined set the capture-type (ctype)
          switch -glob $sinterface {
            [c|C]ontrol* {set ctype control}
            default {set ctype Interface}
            }
    }
    # if duration or size were not initially defined ask user
    if { $duration == {} || $size == {} } {
        if {$duration == {}} {
            set valid_num 0
            while {$valid_num == 0} {
                puts -nonewline "\nHow long to run capture? <5-300 seconds> \[Default=20\] :  "
                flush stdout
                gets stdin {duration}
                if {$duration == ""} {
                    set duration 20
                    incr valid_num
                }
                set results [verify_number_range [string trim $duration] 5 300]
                if {$results == 0} {
                    puts "Invalid Duration Time"
                } else {
                    incr valid_num
                }
            }
        }
        if {$size == {}} {
            set valid_num 0
            while {$valid_num == 0} {
               puts -nonewline "\nMax Capture size? <1-50 MB> \[Default=10\] : "
               flush stdout
               gets stdin {size}
               if {$size == ""} {
                   set size 10
                   incr valid_num
               }
               set results [verify_number_range [string trim $size] 1 50]
                   if {$results == 0} {
                       puts "Invalid Size"
                   } else {
                       incr valid_num
                   }
            }
            if {[string trim $size] > 0} {} else {set size 10}
        }
        startcapture $version $protocol $ipsource $ipdest $ctype $sinterface $duration $size $mtu
    } else {
        startcapture $version $protocol $ipsource $ipdest $ctype $sinterface $duration $size $mtu
    }
}

# redirect program to function that houses commands needed to do packet capture based on paltform version
proc versionsearch {version protocol ipsource ipdest ctype sinterface duration size mtu} {
    # -glob will provide regex searching via wildcard matching "*"
    # if no match inform platform is unsupported
    switch -glob $version {
       9*   {capture_commands9000 $protocol $ipsource $ipdest $ctype $sinterface $duration $size $mtu}
       44*  {capture_commands4400 $protocol $ipsource $ipdest $ctype $sinterface $duration $size $mtu}
       1004 {capture_commands4400 $protocol $ipsource $ipdest $ctype $sinterface $duration $size $mtu}
       45*  {capture_commands4500 $protocol $ipsource $ipdest $ctype $sinterface $duration $size $mtu}
       38*  {capture_commands3800 $protocol $ipsource $ipdest $ctype $sinterface $duration $size $mtu}
       3*   {capture_commands3000 $protocol $ipsource $ipdest $ctype $sinterface $duration $size $mtu}
       100* {capture_commands1000 $protocol $ipsource $ipdest $ctype $sinterface $duration $size $mtu}
       default {puts "Unsupported Version!"}
    }
}


# function to provide confirmation before execution of capture commands
proc startcapture {version protocol ipsource ipdest ctype sinterface duration size mtu} {
      # provided print out on screen what the capture will 'capture' and what are the limitations
      # Includes warnings and termination messages if user requrements are in question or unreasonable
      puts "Capture Overview\n"
      # 'repeat' will print the '-' based on the number of times declared next to it
      puts [string repeat - 37]
      if {$sinterface != "nothing" || $sinterface == "control"} {
        puts "Capture: $sinterface \nDuration: $duration Sec \nFile Size: $size MB \nMax Packet Size: $mtu bytes"
      } else {
        puts "Capture Type: Control-Plane \nDuration: $duration Sec \nFile Size: $size MB\nMax Packet Size: $mtu bytes"
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
      # want to make sure there is enough storage 
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
        y* { versionsearch $version $protocol $ipsource $ipdest $ctype $sinterface $duration $size $mtu}
        default { puts "\nCanceling!" }
    }
}

# function to build acl format to create acl to filter captured packets
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
                set source_dest "permit $protocol host $ipsource host $ipdest"
                set dest_source "permit $protocol host $ipdest host $ipsource"
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
                    set source_dest "permit $protocol any host $ipdest"
                    set dest_source "permit $protocol host $ipdest any"
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
                    set source_dest "permit $protocol host $ipsource any"
                    set dest_source "permit $protocol any host $ipsource"
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

# function to provide status of capture session
proc check_capture_status {} {
    switch -glob $::version {
        356* {set status [exec "show monitor capture point POINT"]}
        default {set status [exec "show monitor capture CAPTURE"]} } 
    if {[regexp {Inactive} $status]} {
        # capture is not operational
        return 0
    } else {
        # capture is operational
        return 1
    }
    puts status
}

# function to display moving progress bar
# will check to see if capture is actually running,
# usually will run for the full duration time period
proc run_progress_bar {total} {
    set finished "false"
    set startcheck 0
    set started_succesfully -1
    for {set i 0} {$i <= [expr $total]} {incr i} {
        if {$i == 0} {puts "\nStarting!\n"}
        progressbar $i $total
        flush stdout
        if {$finished == "true"} { return }
        after 1000
        if {$i == 1} {set startcheck [check_capture_status]
           if {$startcheck == 1} {
               set started_succesfully 1
           } else {
               after 2000
               set startcheck [check_capture_status]
               if {$startcheck == 1} {
                set started_succesfully 1
               } else {
               set started_succesfully 0
               puts "\nFailed to start capture, check logs and investigate\n"
               }
           }
        }
        if { [expr {($i % 3) == 0}]} {
            #check every 3 seconds if completed or never started.
            set currentstatus [check_capture_status]
            # If started_successfully is 1 then capture was "Active" based on show command
            # is currentstatus changes to 0 then capture is "Inactive" based on show command
            # if 1 and 0 then capture may have reached size limit and early terminated capture
            # else 0 and 0 then capture didn't seem to start 3 secs into start
            if { $started_succesfully == 1 && $currentstatus == 0} {set i [expr $total - 1]; set finished "true"}
            if { $started_succesfully == 0 && $currentstatus == 0 && $i < [expr $total - 2]} {
                puts ""
                puts "Capture didn't seem to start, please check logs"
                set i [expr $total + 1]
                set finished "true"
            }
        }
    }
}

# function for capture commands on 3000 series switches except for 3850
proc capture_commands3000 { protocol ipsource ipdest ctype sinterface duration size mtu} {
    perform "monitor capture point stop all"
    if {[file exists flash:CAPTURE.pcap]} {
        debugputs "Deleting flash:CAPTURE.pcap"
        file delete -force -- flash:CAPTURE.pcap
        }
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
    debugputs "\(INFO\) Max MTU capture set to $mtu"
    perform "monitor capture buffer BUFF max-size $mtu"
    if {$ctype == "control"} {
       perform "monitor capture point ip process-switched POINT both"
    } else { 
      perform "monitor capture point ip cef POINT $sinterface both" 
    }
    perform "monitor capture point associate POINT BUFF"
    # <wait> show monitor capture buffer BUFF parameters
    # <wait> or show monitor capture buffer BUFF dump
    perform "monitor capture point start POINT"
    run_progress_bar $duration
    puts ""
    debugputs "\(INFO\) Checking capture status"
    set check [perform "show monitor capture point POINT"]
    set stop 0
    while {$stop < 2} {
        # if the progress bar is done, need to check if the device correctly stops the capture, possible it needs to convert
        # capture to pcap output.  If the capture is still running after 2 intervals of 3 seconds (6 sec) then manually stop capture
        if {[regexp {Inactive} $check]} {
            set stop 3;
        } else {
            puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture point POINT"]; incr stop
        }
    }
    perform "monitor capture point stop POINT"
    puts "Exporting capture to flash:CAPTURE.pcap"
    # export packets in memory to flash as a pcap file
    perform "monitor capture buffer BUFF export flash:CAPTURE.pcap"
    # delete all capture commands and ACL
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
      

# 4500 switches need a secondary interface to get bi-directional traffic (read on capture_commands4500 function comments)
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

# function to perform capturing commands on the catalyst 4500 platform
proc capture_commands4500 { protocol ipsource ipdest ctype sinterface duration size mtu} {
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    # 4500 seems to have any 'inbound' only limitation for capturing TCP traffic.
    # In order to capture bi-directional traffic need to capture on 2nd interface inbound where its going and coming.
    # Because 2 interfaces are monitored there needs to be filtering to capture only traffic destined to monitor interface
    # and if 'any any' is defined then you might capture lots of irrelivant information.  Single SOURCE IP is a protection
    # for busy uplink interfaces if monitoring an access port
    if {[regexp {any} $ipsource] && [regexp {any} $ipdest] && $ctype != "control"} {
          puts "\n"
          puts "***FAILURE*** Both IP source and IP destination are \"any any\", needs to have single SOURCE IP. \n\n\[ENDING PROGRAM\]"
          perform "no monitor capture CAPTURE"
          perform "no ip access-list extended CAPTURE-FILTER" iosconfig
          perform "no class-map CAPTURE_CLASS_MAP" iosconfig
          return
       }
    if {$ctype != "control"} {
        # using destlookupnexthop funtion to search and return nexthop interface to monitor
        # if no destination ip is provide look for the default route nexthop interface
        # else provide the next hop for the destination ip provided
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
            ios_config "ip access-list extended CAPTURE-FILTER" "$any_s_d"
            debugputs "ip access-list extended CAPTURE-FILTER $any_s_d"
            set captureacl "$any_s_d"
        } else {
            ios_config "ip access-list extended CAPTURE-FILTER" "$source_dest" "$dest_source"
            debugputs "ip access-list extended CAPTURE-FILTER"
            debugputs "  $source_dest"
            debugputs "  $dest_source"
            set captureacl "$source_dest \n $dest_source"
        }
  
    perform "no monitor capture CAPTURE"
    perform "no class-map CAPTURE_CLASS_MAP" iosconfig
    if {[file exists bootflash:CAPTURE.pcap]} {
        debugputs "Deleting bootflash:CAPTURE.pcap"
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
        noexec_perform "monitor capture CAPTURE limit duration $duration packet-len $mtu"
    } else { 
          noexec_perform "monitor capture CAPTURE class-map CAPTURE_CLASS_MAP"
          noexec_perform "monitor capture CAPTURE limit packet-len $mtu"
          noexec_perform "monitor capture CAPTURE interface $sinterface both file location bootflash:CAPTURE.pcap buffer-size $buffersize size $size limit duration $duration"
      if {[info exists additionalinterface]} {
          noexec_perform "monitor capture CAPTURE interface $additionalinterface in"
        }
    }

    noexec_perform "monitor capture CAPTURE start"
    run_progress_bar $duration
    puts ""
    set check [perform "show monitor capture CAPTURE"]
    set stop 0
    while {$stop < 2} {
        # if the progress bar is done, need to check if the device correctly stops the capture, possible it needs to convert
        # capture to pcap output.  If the capture is still running after 2 intervals of 3 seconds (6 sec) then manually stop capture
        if {[regexp {Inactive} $check]} {
            set stop 3;
        } else {
            puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture CAPTURE"]; incr stop
        }
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


proc capture_commands9000 { protocol ipsource ipdest ctype sinterface duration size mtu} {
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    set aclresults [split [acl_generator $protocol $ipsource $ipdest] ":"]
    if {[llength $aclresults] == 1} {
      set any_s_d [lindex $aclresults 0]
    } else {
      set source_dest [lindex $aclresults 0]
      set dest_source [lindex $aclresults 1]
    }
    if { [info exists any_s_d] } {
            ios_config "ip access-list extended CAPTURE-FILTER" "$any_s_d"
            debugputs "ip access-list extended CAPTURE-FILTER $any_s_d"
            set captureacl "$any_s_d"
        } else {
            ios_config "ip access-list extended CAPTURE-FILTER" "$source_dest" "$dest_source"
            debugputs "ip access-list extended CAPTURE-FILTER"
            debugputs "  $source_dest"
            debugputs "  $dest_source"
            set captureacl "$source_dest \n $dest_source"
        }

    perform "no monitor capture CAPTURE"
    puts ""
    if {[file exists flash:CAPTURE.pcap]} {
        debugputs "Deleting flash:CAPTURE.pcap"
        file delete -force -- flash:CAPTURE.pcap
        }
    set buffsize [expr $size * 1000]
    noexec_perform "monitor capture CAPTURE access-list CAPTURE-FILTER"
    noexec_perform "monitor capture CAPTURE file location flash:CAPTURE.pcap buffer-size $size size $size"
    noexec_perform "monitor capture CAPTURE limit duration $duration packet-len $mtu"
    if {$ctype == "control"} {
      noexec_perform "monitor capture CAPTURE control-plane both"
    } else { 
      noexec_perform "monitor capture CAPTURE interface $sinterface both"
      }
    noexec_perform "monitor capture CAPTURE start"
    run_progress_bar $duration
    puts ""
    set check [perform "show monitor capture CAPTURE"]
    set stop 0
    while {$stop < 2} {
        # if the progress bar is done, need to check if the device correctly stops the capture, possible it needs to convert
        # capture to pcap output.  If the capture is still running after 2 intervals of 3 seconds (6 sec) then manually stop capture
        if {[regexp {Inactive} $check]} {
            set stop 3;
        } else {
            puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture CAPTURE"]; incr stop
        }
    }
    puts "Exporting capture to flash:CAPTURE.pcap \(Warning slow\)"
    perform "monitor capture CAPTURE stop"
    perform "no monitor capture CAPTURE"
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    puts "\nDone!\n"
    puts "'show monitor capture file flash:CAPTURE.pcap' to see local wireshark summary"
    finish_statement
}

# function for 3850 platform
proc capture_commands3800 { protocol ipsource ipdest ctype sinterface duration size mtu} {
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    set aclresults [split [acl_generator $protocol $ipsource $ipdest] ":"]
    if {[llength $aclresults] == 1} {
      set any_s_d [lindex $aclresults 0]
    } else {
      set source_dest [lindex $aclresults 0]
      set dest_source [lindex $aclresults 1]
    }
    if { [info exists any_s_d] } {
            ios_config "ip access-list extended CAPTURE-FILTER" "$any_s_d"
            debugputs "ip access-list extended CAPTURE-FILTER  $any_s_d"
            set captureacl "$any_s_d"
        } else {
            ios_config "ip access-list extended CAPTURE-FILTER" "$source_dest" "$dest_source"
            debugputs "ip access-list extended CAPTURE-FILTER"
            debugputs "  $source_dest"
            debugputs "  $dest_source"
            set captureacl "$source_dest \n $dest_source"
        }
    perform "no monitor capture CAPTURE"
    perform "no class-map CAPTURE_CLASS_MAP" iosconfig
    if {[file exists flash:CAPTURE.pcap]} {
        debugputs "Deleting flash:CAPTURE.pcap"
        file delete -force -- flash:CAPTURE.pcap
        }
    ios_config "class-map CAPTURE_CLASS_MAP" "match access-group name CAPTURE-FILTER"
    debugputs "class-map CAPTURE_CLASS_MAP"
    debugputs "    match access-group name CAPTURE-FILTER"
    if {$ctype == "control"} {
      noexec_perform "monitor capture CAPTURE class-map CAPTURE_CLASS_MAP "
      noexec_perform "monitor capture CAPTURE limit packet-len $mtu"
      noexec_perform "monitor capture CAPTURE file location flash:CAPTURE.pcap buffer-size $size limit duration $duration"
      noexec_perform "monitor capture CAPTURE control-plane both "
    } else { 
          noexec_perform "monitor capture CAPTURE class-map CAPTURE_CLASS_MAP"
          noexec_perform "monitor capture CAPTURE limit packet-len $mtu"
          noexec_perform "monitor capture CAPTURE file location flash:CAPTURE.pcap buffer-size $size limit duration $duration"
          noexec_perform "monitor capture CAPTURE interface $sinterface both "
      }
    noexec_perform "monitor capture CAPTURE start"
    run_progress_bar $duration
    puts ""
    set check [perform "show monitor capture CAPTURE"]
    set stop 0
    while {$stop < 2} {
        # if the progress bar is done, need to check if the device correctly stops the capture, possible it needs to convert
        # capture to pcap output.  If the capture is still running after 2 intervals of 3 seconds (6 sec) then manually stop capture
        if {[regexp {Inactive} $check]} {
            set stop 3;
        } else {
            puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture CAPTURE"]; incr stop
        }
    }
    perform "monitor capture CAPTURE stop"
    perform "no monitor capture CAPTURE"
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    perform "class-map CAPTURE_CLASS_MAP" iosconfig
    puts "\nDone!\n"
    finish_statement
}

# function to run capture commands for 4400 platform
proc capture_commands4400 { protocol ipsource ipdest ctype sinterface duration size mtu} {
    # make sure not left over config from previous session
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    set aclresults [split [acl_generator $protocol $ipsource $ipdest] ":"]
    if {[llength $aclresults] == 1} {
      set any_s_d [lindex $aclresults 0]
    } else {
      set source_dest [lindex $aclresults 0]
      set dest_source [lindex $aclresults 1]
    }
    if { [info exists any_s_d] } {
            ios_config "ip access-list extended CAPTURE-FILTER" "$any_s_d"
            debugputs "ip access-list extended CAPTURE-FILTER $any_s_d"
            set captureacl "$any_s_d"
        } else {
            ios_config "ip access-list extended CAPTURE-FILTER" "$source_dest" "$dest_source"
            debugputs "ip access-list extended CAPTURE-FILTER"
            debugputs "  $source_dest"
            debugputs "  $dest_source"
            set captureacl "$source_dest \n $dest_source"
        }
    # make sure no capture session is running by deleting it
    perform "no monitor capture CAPTURE"
    puts ""
    if {[file exists flash:CAPTURE.pcap]} {
        debugputs "Deleting flash:CAPTURE.pcap"
        file delete -force -- flash:CAPTURE.pcap
        }
    if {$ctype == "control"} {
      noexec_perform "monitor capture CAPTURE limit packet-len $mtu duration $duration" 
      noexec_perform "monitor capture CAPTURE access-list CAPTURE-FILTER buffer size $size control-plane both"
    } else { 
      noexec_perform "monitor capture CAPTURE limit packet-len $mtu duration $duration "
      noexec_perform "monitor capture CAPTURE access-list CAPTURE-FILTER buffer size $size interface $sinterface both"
      }
    noexec_perform "monitor capture CAPTURE start"
    run_progress_bar $duration
    puts ""
    set check [perform "show monitor capture CAPTURE"]
    set stop 0
    while {$stop < 2} {
        # if the progress bar is done, need to check if the device correctly stops the capture, possible it needs to convert
        # capture to pcap output.  If the capture is still running after 2 intervals of 3 seconds (6 sec) then manually stop capture
        if {[regexp {Inactive} $check]} {
            set stop 3;
        } else {
            puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture CAPTURE"]; incr stop
        }
    }
    debugputs "\(INFO\) Exporting capture to bootflash:CAPTURE.pcap"
    perform "monitor capture CAPTURE stop"
    perform "monitor capture CAPTURE export bootflash:CAPTURE.pcap"
    # delete all capture commands and ACL
    perform "no monitor capture CAPTURE"
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    puts "\nDone!\n"
    finish_statement
}

proc capture_commands1000 { protocol ipsource ipdest ctype sinterface duration size mtu} {
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    set aclresults [split [acl_generator $protocol $ipsource $ipdest] ":"]
    if {[llength $aclresults] == 1} {
      set any_s_d [lindex $aclresults 0]
    } else {
      set source_dest [lindex $aclresults 0]
      set dest_source [lindex $aclresults 1]
    }
    if { [info exists any_s_d] } {
            ios_config "ip access-list extended CAPTURE-FILTER" "$any_s_d"
            debugputs "ip access-list extended CAPTURE-FILTER $any_s_d"
            set captureacl "$any_s_d"
    } else {
            ios_config "ip access-list extended CAPTURE-FILTER" "$source_dest" "$dest_source"
            debugputs "ip access-list extended CAPTURE-FILTER"
            debugputs "  $source_dest"
            debugputs "  $dest_source"
            set captureacl "$source_dest \n $dest_source"
    }
  
    perform "no monitor capture CAPTURE"
    if {[file exists flash:CAPTURE.pcap]} {
        debugputs "Deleting flash:CAPTURE.pcap"
        file delete -force -- flash:CAPTURE.pcap
    }
    noexec_perform "monitor capture CAPTURE limit packet-len $mtu"
    noexec_perform "monitor capture CAPTURE access-list CAPTURE-FILTER"
    noexec_perform "monitor capture CAPTURE buffer size $size"
    noexec_perform "monitor capture CAPTURE limit duration $duration"
  
    if {$ctype == "control"} {
      noexec_perform "monitor capture CAPTURE control-plane both"
    } else { 
      noexec_perform "monitor capture CAPTURE interface $sinterface both"
    }
    noexec_perform "monitor capture CAPTURE start"
    # diplay a progress bar passing how long it will run 
    run_progress_bar $duration
    puts ""
    set check [perform "show monitor capture CAPTURE"]
    set stop 0
    while {$stop < 2} {
        # if the progress bar is done, need to check if the device correctly stops the capture, possible it needs to convert
        # capture to pcap output.  If the capture is still running after 2 intervals of 3 seconds (6 sec) then manually stop capture
        if {[regexp {Inactive} $check]} {
            set stop 3;
        } else {
            puts "Compiling packet capture to pcap format..."; after 3000; set check [exec "show monitor capture CAPTURE"]; incr stop
        }
    }
    debugputs "\(INFO\)Exporting capture to flash:CAPTURE.pcap"
    perform "monitor capture CAPTURE stop"
    perform "monitor capture CAPTURE export flash:CAPTURE.pcap"
    # delete all capture commands and ACL
    perform "no monitor capture CAPTURE"
    perform "no ip access-list extended CAPTURE-FILTER" iosconfig
    puts "\nDone!\n"
    finish_statement
}

proc finish_statement {} {
    # find current logged in user using "who" and locating astriek * next to username
    # sometimes the username is cut off if name is too long, so need to use secondary lookup via "aaa sessions"
    # there are times when logged in multiple times to same device can cause multiple aaa sessions, so filter multiple results
    # to first found username that matches if multiple returned
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
    # Display output for Windows Command Prompt, cut and paste to get pcap and opens wireshark
    set cmdhelper "Windows CMD \'scp $current_user"
    append cmdhelper "@"
    append cmdhelper [string range $current_ip 0 end-3]
    append cmdhelper ":CAPTURE.pcap . & .\\CAPTURE.pcap'"
    puts $cmdhelper
    # Display output for Powershell, cut and paste to get pcap and opens wireshark
    set cmdhelper "Windows Powershell \'scp $current_user"
    append cmdhelper "@"
    append cmdhelper [string range $current_ip 0 end-3]
    append cmdhelper ":CAPTURE.pcap . ; .\\CAPTURE.pcap'"
    puts $cmdhelper

}


proc cli_show_filters { version } {
    # version will determine which help to display
    # Using switch loop to display correct filter, glob argument provides a regex like match
    # bootflash is string argument passed to cli_filter_help
    switch -glob $version {
        9*   {cli_filter_help}
        45*  {cli_filter_help bootflash}
        38*  {cli_filter_help}
        356* {puts "CLI File Display on this device type is Unsupported. Must SCP to local Computer!"}
        1004 {puts "CLI File Display on this device type is Unsupported. Must SCP to local Computer!"}
        100* {cli_filter_help}
        default {puts "CLI File Display on this device type is Unsupported. Must SCP to local Computer!"}
    }
}

proc cli_filter_help {{storage flash}} {
   puts "
   
    #Basic filters
       show monitor capture file $storage:CAPTURE.pcap brief
       show monitor capture file $storage:CAPTURE.pcap display-filter icmp
       show monitor capture file $storage:CAPTURE.pcap display-filter tcp 
       show monitor capture file $storage:CAPTURE.pcap display-filter udp 
    
    #Routing protocols
       show monitor capture file $storage:CAPTURE.pcap display-filter \"eigrp || ospf || tcp.port == 179\"
    
    #Web traffic
       show monitor capture file $storage:CAPTURE.pcap display-filter \"tcp.port == 80 || tcp.port == 443\"
    
    #DHCP
       show monitor capture file $storage:CAPTURE.pcap display-filter dhcp
    
    #DNS
       show monitor capture file $storage:CAPTURE.pcap display-filter \"udp.port == 53\"
    
    #Traffic to or from IP
       \[First example does src \'and\' dst for 1.1.1.1 use ip.addr\]
       show monitor capture file $storage:CAPTURE.pcap display-filter \"ip.addr == 1.1.1.1\"
       show monitor capture file $storage:CAPTURE.pcap display-filter \"ip.src_host == 1.1.1.1\"
       show monitor capture file $storage:CAPTURE.pcap display-filter \"ip.dst_host == 1.1.1.1\"
    
    #TCP Rest Flag
       Show monitor capture file $storage:CAPTURE.pcap display-filter \"tcp.flags.reset == 1\"
    
   "
}


proc displayhelp {} {
    # Help output for methods and option for useage
    puts "\n\n Examples:
         \[syntax\] wireshark <protocol> <source_ip:\[port\]> <dest_ip:\[port\]> <control|interface> <duration ses> <capture size MB> <packet-len>
                                                                                                   20 sec           10 MB          172 mtu
         wireshark ip any any 
         wireshark ip 192.168.25.2 any
         wireshark ip 192.168.25.2 192.168.30.20 Gi1/0/1
         wireshark ip 192.168.25.2 192.168.30.20 Gi1/0/1 40 10
         wireshark ip 192.168.25.2 192.168.30.20 control 60 30
    
         wireshark tcp any any 
         wireshark tcp 192.168.25.2 any:80
         wireshark tcp 192.168.25.2 192.168.30.20:443 Gi1/0/1
         wireshark tcp 192.168.25.2:443 192.168.30.20 Gi1/0/1 40 10 1500
    
         wireshark udp any any 
         wireshark udp 192.168.25.2 any
         wireshark udp 192.168.25.2 192.168.30.20:53 Gi1/0/1
         wireshark udp 192.168.25.2:53 192.168.30.20 Gi1/0/1 40 10
 
         \[syntax\] wireshark erspan <protocol> <source_ip> <dest_ip> <collector ip> <monitor interface> <ERSPAN source ip> <max duration sec> \<direction\>
         wireshark erspan ip any any
         wireshark erspan ip any any 172.33.11.23 Gi1/0/1
         wireshark erspan ip any any 172.33.11.23 Gi1/0/1 2.2.2.2
         wireshark erspan ip any any 172.33.11.23 Gi1/0/1 2.2.2.2 50
         wireshark erspan ip any any 172.33.11.23 Gi1/0/1 2.2.2.2 50 rx
         wireshark erspan --debug tcp any any 172.33.11.23

         ***If you want display pcap on cli examples:
         wireshark filter

         ***If you want to see commands used:
         wireshark --debug <protocol> <source_ip:\[port\]> <dest_ip:\[port\]> (including remainder options)
       
         Supported platfroms:
         CSR1000v, ASR1004, 3560, 3850, 4400, 4500 (sup-8), 9300, 9400
       "
}

proc getversion {} {
    # Find version of device, "show version" then regex find in output the version,
    #  Search for model number line that contain model type. Usually 3560, 9300, 9400
    # Foreach will loop through every line via "\n" from output and look for "model
    # number", once found split the line via spaces in regex -inline -all and gather
    # 3rd element.
    set get_version [exec "show ver"]
    foreach {line} [split $get_version "\n"]  {
        if {[regexp -nocase "model number" $line]} {
            set found_version [lindex [regexp -all -inline {\S+} $line] 3]
        }
    }
    # Most Platforms do not have 'model number' line, 
    #   manual search for supported platforms via regex
    if {![info exists found_version]} {
       foreach {line} [split $get_version "\n"]  {
            if {[regexp {(CSR1000V)|(C45\d\d)|(ASR100\d)|(ISR44\d\d)} $line]} {
               set found_version [lindex [regexp -all -inline {\S+} $line] 1]
            } 
        }
    }
    # Stop program an inform user device will not work.
    # Checking to see if found_version variable is created
    if {![info exists found_version]} {
        puts "Unable to determine platform. "
        return 0
    }
    # If device is found get version number and save to $version variable
    if {[regexp {\d\d\d\d*} $found_version]} {
        global version
        set version [lindex [regexp -inline {\d\d\d\d} $found_version] 0]
        return "$version"
    } else {
        puts "Unable to determine platform. "
        return 0
    }
}

proc erspan_16code {protocol ipsource ipdest erspandest {sinterface ""} {originip ""} {duration ""} {direction ""} {silent ""}} {

    if {$sinterface == ""} {
        # If interface not provide at start ask for interface
        puts "\nAvailable Interfaces:"
        # Grab interfaces from "show ip interface brief" and using regex to grap interface names into a list
        set foundinterfaces [regexp -all -inline {[A-Za-z-]+\d\/?\d?\/?\d?\/?\d?\d?} [exec "show ip int br"]] 
        # find longest interface name for padding on display, used in format below
        set largestinterfacesize [expr [getlargest_interface $foundinterfaces] + 2]
        foreach {a b c d e} [join $foundinterfaces " "] {
            # add padding for clean looking screen display
            set a [format {%-*s} $largestinterfacesize  $a]
            set b [format {%-*s} $largestinterfacesize  $b]
            set c [format {%-*s} $largestinterfacesize  $c]
            set d [format {%-*s} $largestinterfacesize  $d]
            set e [format {%-*s} $largestinterfacesize  $e]
            # creates 5 column print based on padding
            puts "$a $b $c $d $e"} 
        set i 0
        puts " "
        while {$i < 1} {
           puts "Which interface to ERSPAN Monitor \[exact name needed\]?"
           puts -nonewline "\nSelection: "
           flush stdout
           gets stdin {sinterface}
           if {$i > 0} {continue} else {}
           # simple error checking via searching interface list with its exact name from user input
           if {[lsearch -exact $foundinterfaces "$sinterface"] == -1} { puts "\nInterface Not found...\n"} else {incr i}
        }
    }
    if {$originip == ""} {
        set ipaddress_available [perform "show ip int br | i Loopback"]
        set valid_ip 0
        if {$ipaddress_available != "" && [lindex [regexp -all -inline {\S+} $ipaddress_available] 1] != "unassigned"} {
            set originip [lindex [regexp -all -inline {\S+} $ipaddress_available] 1]
        } else {
            while {$valid_ip < 1} {
                puts -nonewline "Unable to located loopback IP.  What ip will the ERSPAN session use as source IP \[Default=1.1.1.1\] :  "
                flush stdout
                gets stdin {originip}
                if {$originip == ""} {
                    set originip "1.1.1.1"
                }
                set valid_ip [verify_valid_ip $originip]
            }
        }
    }
    if {$duration == ""} {
        set valid_num 0
        while {$valid_num == 0} {
            puts -nonewline "For safety measure how long to run ERSPAN, in seconds <5-300 recommended> \[Default 30\]:  "
            flush stdout
            gets stdin {duration}
            if {$duration == ""} {
                set duration 30
                incr valid_num
            }
            set results [verify_number_range $duration 5 300]
            if {$results == 0} {
                puts "Invalid Duration Time"
            } else {
                incr valid_num
            }
        }
    }
    if {$direction == ""} {
        set transmit 0
        while {$transmit == 0} {
            puts -nonewline "Capture Direction (rx,tx,both) \[Default=both\]:  "
            flush stdout
            gets stdin {direction}
            if {$direction == ""} {
                set direction both
                incr transmit
            }
            if {[string trim $direction] == "rx" || [string trim $direction] == "tx" || [string trim $direction] == "both"} {
                incr transmit
            } else {
                puts "Invalid direction"
            }
        }
    }
    puts "\n"
    puts [string repeat * 50]
    puts "ERSPAN Montior Interface: $sinterface "
    puts "ERSPAN Direction Cap: $direction"
    if { $ipsource == "any" && $ipdest == "any" } {
        puts "ERSPAN ACL: $protocol any any"
    } else {
        puts "ERSPAN ACL: $protocol $ipsource $ipdest 
            $protocol $ipdest $ipsource"
    }
    puts "ERSPAN Destination: $erspandest "
    puts "ERSPAN Origin IP: $originip "
    puts "ERSPAN max duration: $duration sec"
    puts [string repeat * 50]
    puts ""
    #puts [string repeat * 50]
    puts "\n    If ERSPAN is destined to local computer with wireshark in default location
    you can open 'CMD' or 'Powershell' \: \"C:\\Program Files\\Wireshark\\Wireshark.exe\" -f \"ip proto 0x2f\""
    puts "    \[IMPORTANT\] ERSPAN encapsulates with GRE headers, verify firewalls on network allow GRE traffic"
    puts ""
    #puts [string repeat * 50]
    puts ""
    if {[string trim $silent] != "silent"} {
        puts -nonewline "Start? \[yes\|no\]: "
        flush stdout
        gets stdin {start}
        switch -glob $start {
          y* {puts "\nStarting..."}
          default { puts "\nCanceling!"; return }
        }
    } else { puts "Silent Mode: on" }
    # Monitor session variables
    set monitor_session "monitor session 15 type erspan-source"
    set monitor_description "description tcl created erspan via wireshark program"
    if {[regexp {[V|v]lan} $sinterface]} {
        set vlannum [string range $sinterface 4 end]
        set monitor_source "source vlan $vlannum $direction"
    } else {
        set monitor_source "source interface $sinterface $direction"
    }
    set monitor_filter "filter ip access-group ERSPAN-FILTER"
    set monitor_destination "destination"
    set monitor_destip "ip address $erspandest"
    set monitor_id "erspan-id 15"
    set monitor_origin "origin ip address $originip"
    set monitor_ttl "ip ttl 10"
    set monitor_end "end"
    # Applet EEM variables
    set emergancy_timer [expr $duration + 5]
    set applet_name "event manager applet ERSPAN_TIMER"
    set applet_descr "description EMERGANCY ERSPAN stop timer"
    set applet_event "event timer countdown time $emergancy_timer "
    set applet_action1 "action 1.0 cli command \"en\""
    set applet_action2 "action 2.0 cli command \"config t\""
    set applet_action3 "action 3.0 cli command \"monitor session 15 type erspan-source\""
    set applet_action4 "action 4.0 cli command \"shutdown\""
    set applet_action5 "action 5.0 syslog msg \" STOPPING ERSAPN\""
    perform "no $applet_name" iosconfig
    after 1000
    debugputs "$applet_name "
    debugputs "  $applet_descr "
    debugputs "  $applet_event"
    debugputs "  $applet_action1"
    debugputs "  $applet_action2"
    debugputs "  $applet_action3"
    debugputs "  $applet_action4"
    debugputs "  $applet_action5"
    debugputs "  exit"
    ios_config $applet_name $applet_descr $applet_action1 $applet_action2 $applet_action3 $applet_action4 $applet_action5 $applet_descr "exit"
    ios_config $applet_name $applet_event "exit"
    perform "no ip access-list extended ERSPAN-FILTER" iosconfig
    set aclresults [split [acl_generator $protocol $ipsource $ipdest] ":"]
    if {[llength $aclresults] == 1} {
      set any_s_d [lindex $aclresults 0]
    } else {
      set source_dest [lindex $aclresults 0]
      set dest_source [lindex $aclresults 1]
    }
    if { [info exists any_s_d] } {
            ios_config "ip access-list extended ERSPAN-FILTER" "$any_s_d"
            debugputs "ip access-list extended ERSPAN-FILTER $any_s_d"
            set erspanacl "$any_s_d"
    } else {
            ios_config "ip access-list extended ERSPAN-FILTER" "$source_dest" "$dest_source"
            debugputs "ip access-list extended ERSPAN-FILTER"
            debugputs "  $source_dest"
            debugputs "  $dest_source"
            set erspanacl "$source_dest \n $dest_source"
    }
    debugputs "$monitor_session"
    debugputs "  $monitor_description "
    debugputs "  $monitor_source "
    debugputs "  $monitor_filter "
    debugputs "  no shutdown"
    debugputs "  $monitor_destination"
    debugputs "     $monitor_destip"
    debugputs "     $monitor_id"
    debugputs "     $monitor_origin"
    debugputs "     $monitor_ttl "
    debugputs "     exit"
    debugputs "  $monitor_end"
    ios_config $monitor_session $monitor_description $monitor_source $monitor_filter "no shut" $monitor_destination $monitor_destip $monitor_id $monitor_ttl monitor_end
    ios_config $monitor_session $monitor_destination $monitor_origin
    #puts ""
    #puts [string repeat * 50]
    #puts "\n    If ERSPAN is destined to local computer with wireshark in default location
    #you can open 'CMD' or 'Powershell' \: \"C:\\Program Files\\Wireshark\\Wireshark.exe\" -f \"ip proto 0x2f\""
    #puts ""
    #puts [string repeat * 50]
    puts ""
    puts "Erspan session will run for $duration seconds"
    puts ""
    run_progress_bar $duration
    puts "\n"
    ios_config $monitor_session "shutdown"
    debugputs "$monitor_session"
    debugputs "  shutdown"
    perform "no $monitor_session" iosconfig
    perform "no ip access-list extended ERSPAN-FILTER" iosconfig
    perform "no event manager applet ERSPAN_TIMER" iosconfig    
    puts "\nDone!\n"
}


proc erspan_setup {protocol ipsource ipdest erspandest {sinterface ""} {originip ""} {duration ""} {direction ""} {silent ""}} {
    # version will determine which help to display
    # Using switch loop to display correct filter, glob argument provides a regex like match
    # bootflash is string argument passed to cli_filter_help
    set version [getversion]
    puts "Device version: $version"
    switch -glob $version {
        9*   {erspan_16code $protocol $ipsource $ipdest $erspandest $sinterface $originip $duration $direction $silent}
        45*  {erspan_4500_15code $protocol $ipsource $ipdest $erspandest $sinterface $originip $duration $direction $silent}
        38*  {erspan_16code $protocol $ipsource $ipdest $erspandest $sinterface $originip $duration $direction $silent}
        1004 {erspan_16code $protocol $ipsource $ipdest $erspandest $sinterface $originip $duration $direction $silent}
        100* {cli_filter_help}
        default {puts "ERSPAN setup not supported on this device!"}
    }
}

proc verify_valid_ip {ip} {
    regexp {^(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?:\.(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}$} $ip match
    if {[info exists match]} {
       return 1
   } else {
       return 0
   }
}

proc verify_number_range {provided beginning ending} {
   set bresult [string is digit -strict $beginning]
   set eresult [string is digit -strict $ending]
   set rprovided [string is digit -strict $provided]
   if {$bresult == 0 || $eresult == 0 || $rprovided == 0 } {
       return 0
   } else {
       if {[expr $provided >= $beginning] == 1 && [expr $provided <= $ending] == 1} {
           return 1
       } else {
           return 0
       }

   }
}

proc verify_valid_aclip {ip} {
    if {$ip == "any"} {
        return 1
    }
    set ipverify [verify_valid_ip $ip]
    if {$ipverify == 1} {
        return 1
    } 
    if {[string match *:* $ip]} {
        set dividedstring [split $ip :]
        if {[lindex $dividedstring 0] == "any" && [string is digit -strict [lindex $dividedstring 1]]} {
            return 1
        }
        if {[verify_valid_ip [lindex $dividedstring 0]] && [string is digit -strict [lindex $dividedstring 1]]} {
            return 1
        }    
    } else {
        return 0
    }
    return 0
}

proc main {} {
    # If no arguments passed to program, display help function to provide help examples.
    # Stop program after help is dispalyed.
    if {$::argc == 0} {
        displayhelp; return
        }
    set version [getversion]
    # If 1 argument and if is the word 'filter' will dispaly helper function for show commands
    # Stop program after help is dispalyed.
    if {$::argc == 1 && [lindex $::argv 0] == "filter"} {
            cli_show_filters $version; return 
        }
    if {([lindex $::argv 0] == "erspan" || [lindex $::argv 1] == "--debug") && $::argc < 5} {
        puts "\nMissing one of the required arguments \<protocol\> \<sourceip|any\> \<destip|any\> <ERSPAN Destip>"; return
    } else {
        if {[lindex $::argv 0] == "erspan" && [lindex $::argv 1] == "--debug"} {
            if {[lindex $::argv 0] == "erspan"} {
                clear_screen 
                global debug; set debug 1
                eval erspan_setup [lrange $::argv 2 end]
                return
            } else {
                puts "\nInvalid option arrangment"; return
            }
        }
    }
    if {[lindex $::argv 0] == "erspan" && $::argc < 5} {
        puts "\nMissing one of the required arguments \<protocol\> \<sourceip|any\> \<destip|any\> <ERSPAN Destip>"; return
    } elseif {[lindex $::argv 0] == "erspan" && $::argc > 10} {
        puts "\nToo Many arguments. \<protocol\> \<sourceip|any\> \<destip|any\> \<ERSPAN Destip\> \<Interface\> \<ERSPAN Sourceip\> \<duration\>"; return
    } elseif {[lindex $::argv 0] == "erspan" && $::argc >= 5} {
        global debug; set debug 0
        set valid_acl_sourceip 0
        set valid_acl_sourceip [verify_valid_aclip [lindex $::argv 2]]
        if {$valid_acl_sourceip == 0} {
            puts "Invalid ACL Source IP!"
            return
        }
        set valid_acl_destip 0
        set valid_acl_destip [verify_valid_aclip [lindex $::argv 3]]
        if {$valid_acl_destip == 0} {
            puts "Invalid ACL Destination IP!"
            return
        }
        set valid_erspan_destip 0
        set valid_erspan_destip [verify_valid_ip [lindex $::argv 4]]
        if {$valid_erspan_destip == 0} {
            puts "Invalid ERSPAN Destination IP!"
            return
        }
        set valid_erspan_sourceip 0
        if {$::argc >= 7} {
            set valid_erspan_sourceip [verify_valid_ip [lindex $::argv 6]]
            if {$valid_erspan_sourceip == 0} {
                puts "Invalid ERSPAN Source IP!"
                return
            }
            if {$::argc == 8} {
                set results [verify_number_range [lindex $::argv 7] 5 300]
                if {$results == 0} {
                   puts "Invalid Duration Time"
                   return
                }
            }
        }
        clear_screen 
        eval erspan_setup [lrange $::argv 1 end]
        return
    }
    #debug will display commands used during program run
    if {[lindex $::argv 0] == "--debug"} {
        if {[expr $::argc < 4]} {
            puts "\nMissing one of the required arguments \<protocol\> \<sourceip|any\> \<destip|any\>"; return
        } else {
            if {$version == 0} { return }
            set valid_acl_sourceip 0
            set valid_acl_sourceip [verify_valid_aclip [lindex $::argv 2]]
            if {$valid_acl_sourceip == 0} {
                puts "Invalid ACL Source IP!"
                return
            }
            set valid_acl_destip 0
            set valid_acl_destip [verify_valid_aclip [lindex $::argv 3]]
            if {$valid_acl_destip == 0} {
                puts "Invalid ACL Destination IP!"
                return
            }
            clear_screen
            #turn on debug for stdout
            global debug; set debug 1; puts "\[Debugging mode\]"
            eval gatherinformation_and_begin_capture $version [lrange $::argv 1 end]
        }
        return
    } else {
        # if protocol with src and dest, not provide, inform user and end program
        if {$::argc < 3} {
            puts "\nMissing one of the required arguments \<protocol\> \<sourceip|any\> \<destip|any\>"; return
        } else {
            #turn off debug for stdout
            global debug; set debug 0 
            if {$version == 0} { return }
            set valid_acl_sourceip 0
            set valid_acl_sourceip [verify_valid_aclip [lindex $::argv 1]]
            if {$valid_acl_sourceip == 0} {
                puts "Invalid ACL Source IP!"
                return
            }
            set valid_acl_destip 0
            set valid_acl_destip [verify_valid_aclip [lindex $::argv 2]]
            if {$valid_acl_destip == 0} {
                puts "Invalid ACL Destination IP!"
                return
            }
            clear_screen
            eval gatherinformation_and_begin_capture $version [lrange $::argv 0 end]
        }
    }    
}
        
main 

tclquit
