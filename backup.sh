#!/bin/bash
# copy the two maps folder to the backup folder with the date and time
cp -r ./maps ./maps_backup/maps_$(date +%Y-%m-%d_%H-%M-%S)