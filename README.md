# Simple_Packet_Capture
TCL script to automate Embedded Packet Capture (EPC) in Cisco platforms

Create cisco alias: </br>
Upload capture_program.tcl to flash of Cisco device</br>
<b>scp capture_program.tcl \<username>@\<deviceip>:capture_program.tcl</b></br>
</br>
<b>config t</b></br>
<b>alias exec wireshark tclsh flash:capture_program.tcl</b>

# Usage
switch# wireshark </br>

 Examples:
     [syntax] wireshark <protocol> <source_ip:[port]> <dest_ip:[port]> <capture_type> <duration_seconds> <capture_size_MB> <mtu>
        
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
 
         [syntax] wireshark erspan <protocol> <source_ip> <dest_ip> <collector ip> <monitor interface> <ERSPAN source ip> <max duration sec> <direction>
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
     

# Normal Run
![Image of Help](https://github.com/settlej/Simple_Packet_Capture/blob/master/screen_shots/normal.gif)</br></br>
# Debug Run
![Image of Help](https://github.com/settlej/Simple_Packet_Capture/blob/master/screen_shots/debug.gif)</br></br>
# ERSPAN Run
![Image of Help](https://github.com/settlej/Simple_Packet_Capture/blob/master/screen_shots/erspandemo.gif)</br></br>
# Help and Info
![Image of Help](https://github.com/settlej/Simple_Packet_Capture/blob/master/screen_shots/help.gif)</br></br>
