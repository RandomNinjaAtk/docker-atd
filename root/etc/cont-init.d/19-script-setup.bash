#!/usr/bin/with-contenv bash

# create scripts directory if missing
if [ ! -d "/config/scripts" ]; then
	mkdir -p "/config/scripts"
else
	echo "Updating scripts..."
	rm -rf /config/scripts/*
fi

if [ -d "/config/scripts" ]; then
	cp -r /scripts/* /config/scripts/
fi

# create cache directory if missing
if [ ! -d "/config/cache" ]; then
	mkdir -p "/config/cache"
fi

# create logs directory if missing
if [ ! -d "/config/logs" ]; then
	mkdir -p "/config/logs"
fi

# create list directory if missing
if [ ! -d "/config/list" ]; then
	mkdir -p "/config/list"
fi

# create list directory if missing
if [ ! -d "/config/ignore" ]; then
	mkdir -p "/config/ignore"
fi

# set permissions
chown -R abc:abc "/config"
chown -R abc:abc "/scripts"
chmod 777 -R "/scripts"
chmod 777 -R "/config"

echo "Complete..."

exit $?
