#!/usr/bin/expect -f
#this file will send the current inventory of plugins to console output.
#example usage: ./chuboe_osgi_ss.sh > somefile.txt
#sleep to allow for all plugins to deploy
sleep 60
spawn telnet localhost 12612
send -- "ss\n"
send -- "disconnect\n\n"
expect "$ "