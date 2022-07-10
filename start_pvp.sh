#!/bin/bash
while true
do
    ./minetest/bin/minetestserver --color always --gameid minetest --world ./maps/pvp --config ./maps/pvp.conf --logfile ./maps/pvp/log.txt
    sleep 4
done