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

ClientDownloadMusic () {
    rip url $1 &>/dev/null
}

ClientDownloadVideo () {
    rip url $1 &>/dev/null
}

ClientDownloadMusicVerification () {
    if [ -d "$DownloadLocation/temp" ]; then
		if find $DownloadLocation/temp -type f -iname "*.m4a" | read; then
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