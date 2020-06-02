# Simple_Packet_Capture
TCL script to automate Embedded Packet Capture (EPC) in Cisco platforms

Create cisco alias: </br>
Upload capture_program.tcl to flash of Cisco device</br>
<b>scp capture_program.tcl \<username>@\<deviceip>:capture_program.tcl</b></br>
</br>
<b>config t</b></br>
<b>alias exec wireshark tclsh flash:capture_program.tcl</b>

# Usage
switch# wireshark 
[HELP]:
Provide source and destination {ip|any} with optional interface

 Examples:
     [syntax] wireshark <protocol> <source_ip:[port]> <dest_ip:[port]> <capture_type> <duration_seconds> <capture_size_MB>

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
     
     
