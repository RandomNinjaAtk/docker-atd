#!/usr/bin/with-contenv bash

ClientConfigCheck () {
	
	#check existing config file
	if [ -f /config/streamrip_config.toml ]; then
		if cat /config/streamrip_config.toml | grep "/downloads-atd/temp" | read; then
			log "TIDAL :: Existing config file found with the correct download location"
		else
			log "TIDAL :: ERROR :: Existing config file found with the wrong location, removing to import new config"
			rm -rf "/config/streamrip_config.toml"
		fi
	fi

	# create streamrip config directory if missing
	if [ ! -f /config/streamrip_config.toml ]; then
		if [ -f /config/backup/streamrip_config.toml ]; then
			log "TIDAL :: Importing backup config from \"/config/backup/streamrip_config.toml\""
			cp -p /config/backup/streamrip_config.toml /config/streamrip_config.toml
			# remove backup token
			rm -rf /config/backup/
		else
			log "TIDAL :: No default config found, importing default config from \"/config/streamrip_config.toml\""
			if [ -f "/config/streamrip_config.toml" ]; then
				cp "$SCRIPT_DIR/streamrip_config.toml" /config/streamrip_config.toml
				chmod 777 /config/streamrip_config.toml
			fi
		fi
	fi
	
	TokenCheck=$(cat /config/streamrip_config.toml | grep token_expiry | wc -m)
	if [ $TokenCheck == 18 ]; then
		log "TIDAL :: ERROR :: Loading client for required authentication, please authenticate, then exit the client..."
		rip config --tidal
	fi

	if [ -f /config/streamrip_config.toml ]; then
		if [[ $(find "/config/streamrip_config.toml" -mtime +6 -print) ]]; then
			log "TIDAL :: ERROR :: Token expired, removing..."
			rip config --tidal
		fi
	fi

}

ClientSelfTest () {
	log "SELF TEST :: PERFORMING DL CLIENT TEST"
	ClientDownload "--max-quality 0 https://tidal.com/browse/track/234794"
	if find $DownloadLocation/temp -type f -iname "*.m4a" | read; then
		log "SELF TEST :: SUCCESS"
		if [ -d $DownloadLocation/temp ]; then
			rm -rf $DownloadLocation/temp
		fi
		StartClientSelfTest=PASSED
	else
		if [ -d $DownloadLocation/temp ]; then
			rm -rf $DownloadLocation/temp
		fi
		log "ERROR :: Download unsuccessful, fix streamrip"
		exit
	fi
}

ClientDownload() {
	if [ ! -d "$DownloadLocation/temp" ]; then
		mkdir -p "$DownloadLocation/temp"
	fi
    	rip url $1 -d "$DownloadLocation/temp" --config "/config/streamrip_config.toml"
}

ClientDownloadMusicVerification () {
    if [ -d "$DownloadLocation/temp" ]; then
		if find $DownloadLocation/temp -type f -iname "*.m4a" -o -iname "*.flac" | read; then
			log "$albumlog $track_id_number OF $track_ids_count :: DOWNLOAD :: COMPLETE"
		fi
		DownloadStatus=true
	else
		log "$albumlog $track_id_number OF $track_ids_count :: DOWNLOAD :: FAILED"
		log "$albumlog $track_id_number OF $track_ids_count :: Performing cleanup..."
		if [ ! -d "/config/logs/failed" ]; then
			mkdir -p "/config/logs/failed"
		fi
		touch /config/logs/failed/$album_id
		if [ -d "$DownloadLocation/temp" ]; then
			rm -rf "$DownloadLocation/temp"
		fi
		DownloadStatus=false
	fi
}
