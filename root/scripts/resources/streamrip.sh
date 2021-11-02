ClientConfigCheck () {
	
	#check existing config file
	if [ -f /root/.config/streamrip/config.toml ]; then
		if cat /root/.config/streamrip/config.toml | grep "/downloads-atd/temp" | read; then
			log "TIDAL :: Existing config file found with the correct download location"
		else
			log "TIDAL :: ERROR :: Existing config file found with the wrong location, removing to import new config"
			rm -rf "/root/.config/streamrip"
		fi
	fi

	# create streamrip config directory if missing
	if [ ! -d "/root/.config/streamrip" ]; then
		mkdir -p "/root/.config/streamrip"
		# check for backup token and use it if exists
		if [ ! -f /root/.config/streamrip/config.toml ]; then
			if [ -f /config/backup/streamrip_config.toml ]; then
				log "TIDAL :: Importing backup config from \"/config/backup/streamrip_config.toml\""
				cp -p /config/backup/streamrip_config.toml /root/.config/streamrip/config.toml
				# remove backup token
				rm /config/backup/streamrip_config.toml 
			else
				log "TIDAL :: No default config found, importing default config from \"$SCRIPT_DIR/streamrip_config.toml\""
				if [ -f "$SCRIPT_DIR/streamrip_config.toml" ]; then
					cp "$SCRIPT_DIR/streamrip_config.toml" /root/.config/streamrip/config.toml
					chmod 777 -R /root
				fi
			fi
		fi
	fi
	
	TokenCheck=$(cat /root/.config/streamrip/config.toml | grep token_expiry | wc -m)
	if [ $TokenCheck == 18 ]; then
		log "TIDAL :: ERROR :: Loading client for required authentication, please authenticate, then exit the client..."
		rip config --tidal
	fi

	if [ -f /root/.config/streamrip/config.toml ]; then
		if [[ $(find "/root/.config/streamrip/config.toml" -mtime +6 -print) ]]; then
			log "TIDAL :: ERROR :: Token expired, removing..."
			rip config --tidal
		else
			# create backup of token to allow for container updates
			if [ ! -d /config/backup ]; then
				mkdir -p /config/backup
			else
				rm -rf /config/backup
				mkdir -p /config/backup
			fi
			log "TIDAL :: Backing up config from \"/root/.config/streamrip/config.toml\" to \"/config/backup/streamrip_config.toml\""
			cp -p /root/.config/streamrip/config.toml /config/backup/streamrip_config.toml
		fi
	fi

}

ClientSelfTest () {
	log "SELF TEST :: PERFORMING DL CLIENT TEST"
	ClientDownloadMusic "--max-quality 0 https://tidal.com/browse/track/234794"
	if find $DownloadLocation/temp -type f -iname "*.m4a" | read; then
		log "SELF TEST :: SUCCESS"
		if [ -d $DownloadLocation/temp ]; then
			rm -rf $DownloadLocation/temp
		fi
	else
		if [ -d $DownloadLocation/temp ]; then
			rm -rf $DownloadLocation/temp
		fi
		log "ERROR :: Download unsuccessful, fix streamrip"
		exit
	fi
}

ClientDownload() {
    rip url $1 &>/dev/null
}

ClientDownloadMusicVerification () {
    if [ -d "$DownloadLocation/temp" ]; then
		if find $DownloadLocation/temp -type f -iname "*.m4a" -o -iname "*.flac" | read; then
			log "$albumlog $track_id_number OF $track_ids_count :: DOWNLOAD :: COMPLETE"
		fi
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
		return
	fi
}
