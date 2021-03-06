#!/usr/bin/with-contenv bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
agent="automated-tidal-downloader ( https://github.com/RandomNinjaAtk/docker-atd )"
DownloadLocation="/downloads-atd"
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
appears_on_enabled=false

Configuration () {
	processstartid="$(ps -A -o pid,cmd|grep "start.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	processdownloadid="$(ps -A -o pid,cmd|grep "download.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	log "To kill script, use the following command:"
	log "kill -9 $processstartid"
	log "kill -9 $processdownloadid"
	log ""
	log ""
	sleep 2
	log "############# $TITLE - Music"
	log "############# SCRIPT VERSION 1.0.01"
	log "############# DOCKER VERSION $VERSION"
	log "############# CONFIGURATION VERIFICATION"
	error=0

    

	if [ "$AutoStart" == "true" ]; then
		log "$TITLESHORT Script AutoStart: ENABLED"
		if [ -z "$ScriptInterval" ]; then
			log "WARNING: $TITLESHORT Script Interval not set! Using default..."
			ScriptInterval="15m"
		fi
		log "$TITLESHORT Script Interval: $ScriptInterval"
	else
		log "$TITLESHORT Script AutoStart: DISABLED"
	fi


    if [ ! -f /root/.tidal-dl.json ]; then
        log "TIDAL :: No default config found, importing default config \"tidal.json\""
        if [ -f $SCRIPT_DIR/tidal-dl.json ]; then
            cp $SCRIPT_DIR/tidal-dl.json /root/.tidal-dl.json
            chmod 777 -R /root
        fi
        tidal-dl -o /downloads-atd
        tidal-dl -r P1080
		tidal-dl -q HiFi
    fi
	# check for backup token and use it if exists
	if [ ! -f /root/.tidal-dl.token.json ]; then
		if [ -f /config/backup/tidal-dl.token.json ]; then
			cp -p /config/backup/tidal-dl.token.json /root/.tidal-dl.token.json
			# remove backup token
			rm /config/backup/tidal-dl.token.json
		fi
	fi

	if [ -f /root/.tidal-dl.token.json ]; then
		if [[ $(find "/root/.tidal-dl.token.json" -mtime +6 -print) ]]; then
			log "TIDAL :: ERROR :: Token expired, removing..."
			rm /root/.tidal-dl.token.json
		else
			# create backup of token to allow for container updates
			if [ ! -d /config/backup ]; then
				mkdir -p /config/backup
			fi
			cp -p /root/.tidal-dl.token.json /config/backup/tidal-dl.token.json
		fi
	fi

    if [ ! -f /root/.tidal-dl.token.json ]; then
        log "TIDAL :: ERROR :: Loading client for required authentication, please authenticate, then exit the client..."
        tidal-dl
    fi

	if [ ! -f /root/.tidal-dl.token.json ]; then
        log "TIDAL :: ERROR :: Please run tidal-dl from CLI and authenticate the client, then exit the client..."
        error=1
    fi

	# check for MusicbrainzMirror setting, if not set, set to default
	if [ -z "$MusicbrainzMirror" ]; then
		MusicbrainzMirror=https://musicbrainz.org
	fi
	# Verify Musicbrainz DB Connectivity
	musicbrainzdbtest=$(curl -s -A "$agent" "${MusicbrainzMirror}/ws/2/artist/f59c5520-5f46-4d2c-b2c4-822eabf53419?fmt=json")
	musicbrainzdbtestname=$(echo "${musicbrainzdbtest}"| jq -r '.name')
	if [ "$musicbrainzdbtestname" != "Linkin Park" ]; then
		log "ERROR: Cannot communicate with Musicbrainz"
		log "ERROR: Expected Response \"Linkin Park\", received response \"$musicbrainzdbtestname\""
		log "ERROR: URL might be Invalid: $MusicbrainzMirror"
		log "ERROR: Remote Mirror may be throttling connection..."
		log "ERROR: Link used for testing: ${MusicbrainzMirror}/ws/2/artist/f59c5520-5f46-4d2c-b2c4-822eabf53419?fmt=json"
		log "ERROR: Please correct error, consider using official Musicbrainz URL: https://musicbrainz.org"
		error=1
	else
		log "Musicbrainz Mirror Valid: $MusicbrainzMirror"
		if echo "$MusicbrainzMirror" | grep -i "musicbrainz.org" | read; then
			if [ "$MusicbrainzRateLimit" != 1 ]; then
				MusicbrainzRateLimit="1.5"
			fi
			log "Musicbrainz Rate Limit: $MusicbrainzRateLimit (Queries Per Second)"
		else
			log "Musicbrainz Rate Limit: $MusicbrainzRateLimit (Queries Per Second)"
			MusicbrainzRateLimit="0$(echo $(( 100 * 1 / $MusicbrainzRateLimit )) | sed 's/..$/.&/')"
		fi
	fi

	# verify downloads location
	if [ -d "/downloads-atd" ]; then
		log "Download Location: $DownloadLocation"
	else
	    log "ERROR: Download Location Not Found! (/downloads-atd)"
		log "ERROR: To correct error, please add a \"$DownloadLocation\" volume"
		error=1
	fi

	# verify downloads location
	if [ -d "$DownloadLocation" ]; then
		log "Download Location: $DownloadLocation"
	else
	    log "ERROR: Download Location Location Not Found! ($DownloadLocation)"
		log "ERROR: To correct error, please add a \"$DownloadLocation\" volume"
		error=1
	fi

	SOURCE_CONNECTION="lidarr"

	if [ "$SOURCE_CONNECTION" == "lidarr" ]; then
		log "Music Video Artist List Source: $SOURCE_CONNECTION"

		# Verify Lidarr Connectivity
		lidarrtest=$(curl -s "$LidarrUrl/api/v1/system/status?apikey=${LidarrApiKey}" | jq -r ".version")
		if [ ! -z "$lidarrtest" ]; then
			if [ "$lidarrtest" != "null" ]; then
				log "Music Video Source: Lidarr Connection Valid, version: $lidarrtest"
			else
				log "ERROR: Cannot communicate with Lidarr, most likely a...."
				log "ERROR: Invalid API Key: $LidarrApiKey"
				error=1
			fi
		else
			log "ERROR: Cannot communicate with Lidarr, no response"
			log "ERROR: URL: $LidarrUrl"
			log "ERROR: API Key: $LidarrApiKey"
			error=1
		fi
	fi

	if [ $error = 1 ]; then
		log "Please correct errors before attempting to run script again..."
		log "Exiting..."
		exit 1
	fi
	sleep 5
}

log () {
    m_time=`date "+%F %T"`
    echo $m_time" "$1
}

SelfTest () {
	log "SELF TEST :: PERFORMING DL CLIENT TEST"
	tidal-dl -l "https://tidal.com/browse/track/234794"
	if find $DownloadLocation/Album -type f -iname "*.m4a" | read; then
		log "SELF TEST :: SUCCESS"
		if [ -d $DownloadLocation/Album ]; then
			rm -rf $DownloadLocation/Album
		fi
	else
		if [ -d $DownloadLocation/Album ]; then
			rm -rf $DownloadLocation/Album
		fi
		log "ERROR :: Download unsuccessful, fix tidal-dl"
		exit
	fi
}

LidarrConnection () {

	lidarrdata=$(curl -s --header "X-Api-Key:"${LidarrApiKey} --request GET  "$LidarrUrl/api/v1/Artist/")
	artisttotal=$(echo "${lidarrdata}"| jq -r '.[].sortName' | wc -l)
	lidarrlist=($(echo "${lidarrdata}" | jq -r ".[].foreignArtistId"))
	log "############# Music Downloads"

	for id in ${!lidarrlist[@]}; do
		artistnumber=$(( $id + 1 ))
		mbid="${lidarrlist[$id]}"
		artistdata=$(echo "${lidarrdata}" | jq -r ".[] | select(.foreignArtistId==\"${mbid}\")")
		artistname="$(echo "${artistdata}" | jq -r " .artistName")"
        artistnamepath="$(echo "${artistdata}" | jq -r " .path")"
		sanitizedartistname="$(basename "${artistnamepath}" | sed 's% (.*)$%%g')"
        totaldownloadcount=$(find "$DownloadLocation" -mindepth 1 -maxdepth 3 -type f -iname "$sanitizedartistname -*.mp4" | wc -l)
        if [ -f "/config/logs/$sanitizedartistname-$mbid-music-complete" ]; then
            if ! [[ $(find "/config/logs/$sanitizedartistname-$mbid-musiccomplete" -mtime +7 -print) ]]; then
                log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: Already downloaded all ($totaldownloadcount) videos, skipping until expires..."
                continue
            fi
        fi
        artistfolder="$(basename "${artistnamepath}")"
        mbzartistinfo=$(curl -s -A "$agent" "${MusicbrainzMirror}/ws/2/artist/$mbid?inc=url-rels+genres&fmt=json")
        sleep 1
        tidalurl="$(echo "$mbzartistinfo" | jq -r ".relations | .[] | .url | select(.resource | contains(\"tidal\")) | .resource" | head -n 1)"
	    tidalartistid="$(echo "$tidalurl" | grep -o '[[:digit:]]*')"
        if [ -z "$tidalurl" ]; then 
            mbzartistinfo=$(curl -s -A "$agent" "${MusicbrainzMirror}/ws/2/artist/$mbid?inc=url-rels+genres&fmt=json")
            tidalurl="$(echo "$mbzartistinfo" | jq -r ".relations | .[] | .url | select(.resource | contains(\"tidal\")) | .resource" | head -n 1)"
            tidalartistid="$(echo "$tidalurl" | grep -o '[[:digit:]]*')"
            sleep 1
        fi
        if [ -z "$tidalurl" ]; then 
            log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: ERROR :: musicbrainz id: $mbid is missing Tidal link, see: \"/config/logs/error/$sanitizedartistname.log\" for more detail..."
            if [ ! -d /config/logs/error ]; then
                mkdir -p /config/logs/error
            fi
            if [ ! -f "/config/logs/error/$sanitizedartistname.log" ]; then          
                echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$mbid/relationships for \"${artistname}\" with Tidal Artist Link" >> "/config/logs/error/$sanitizedartistname.log"
            fi
            continue
        fi
        if [ -f "/config/logs/error/$sanitizedartistname.log" ]; then        
            rm "/config/logs/error/$sanitizedartistname.log"
        fi
		SelfTest
        log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: Processing.."
		logheader="$artistnumber of $artisttotal"
		artist_id=$tidalartistid
		ProcessArtist
	done
}

ProcessArtist () {		
      
	
  
	DL_TYPE="ALBUMS"
	
	if [ -d "/config/temp" ]; then
		rf -rf "/config/temp"
		sleep 0.1
	fi
	
	if [ -f "/config/temp" ]; then
		rm "/config/temp"
		sleep 0.1
	fi

	if [ ! -d "/config/cache" ]; then
		mkdir -p "/config/cache"
		sleep 0.1
	fi
	
	if [ ! -f /config/cache/${artist_id}-tidal-artist.json ]; then
		#artist
		curl -s "https://listen.tidal.com/v1/pages/artist?artistId=${artist_id}&locale=en_US&deviceType=BROWSER&countryCode=US" -H 'x-tidal-token: CzET4vdadNUFQ5JU' -o "/config/cache/${artist_id}-tidal-artist.json"
	fi
	artist_data=$(cat "/config/cache/${artist_id}-tidal-artist.json")
	artist_biography="$(echo "$artist_data" | jq -r ".rows[].modules[] | select(.type==\"ARTIST_HEADER\") | .bio.text" | sed -e 's/\[[^][]*\]//g' | sed -e 's/<br\/>//g')"
	artist_picture_id="$(echo "$artist_data" | jq -r ".rows[].modules[] | select(.type==\"ARTIST_HEADER\") | .artist.picture")"
	artist_name="$(echo "$artist_data" | jq -r ".rows[].modules[] | select(.type==\"ARTIST_HEADER\") | .artist.name")"
	artist_picture_id_fix=$(echo "$artist_picture_id" | sed "s/-/\//g")
	thumb="https://resources.tidal.com/images/$artist_picture_id_fix/750x750.jpg"
	log "$logheader :: $artist_name"
	setlog="$artistnumber of $artisttotal :: $artist_name ::"
	log "$setlog PROCESSING"
	if [ -f "/config/logs/musicbrainz-$artist_id" ]; then
		log "$setlog ERROR :: Cannot Find MusicBrainz Artist Match... :: SKIPPING"
		return
	fi
	
	if [ ! -f "/config/cache/musicbrainz_$artist_id" ]; then
		count="0"
		query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://listen.tidal.com/artist/${artist_id}%22&fmt=json")
		count=$(echo "$query_data" | jq -r ".count")
		if [ "$count" == "0" ]; then
			sleep 1.5
			query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://tidal.com/artist/${artist_id}%22&fmt=json")
			count=$(echo "$query_data" | jq -r ".count")
			sleep 1.5
		fi
		
		if [ "$count" == "0" ]; then
			query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22http://tidal.com/artist/${artist_id}%22&fmt=json")
			count=$(echo "$query_data" | jq -r ".count")
			sleep 1.5
		fi
		
		if [ "$count" == "0" ]; then
			query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22http://tidal.com/browse/artist/${artist_id}%22&fmt=json")
			count=$(echo "$query_data" | jq -r ".count")
			sleep 1.5
		fi
		
		if [ "$count" == "0" ]; then
			query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://tidal.com/browse/artist/${artist_id}%22&fmt=json")
			count=$(echo "$query_data" | jq -r ".count")
		fi
	
		if [ "$count" != "0" ]; then
			musicbrainz_main_artist_id=$(echo "$query_data" | jq -r '.urls[]."relation-list"[].relations[].artist.id' | head -n 1)
			sleep 1.5
			artist_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/artist/$musicbrainz_main_artist_id?fmt=json")
			echo "$musicbrainz_main_artist_id" >> /config/cache/musicbrainz_$artist_id
			artist_sort_name="$(echo "$artist_data" | jq -r '."sort-name"')"
			artist_formed="$(echo "$artist_data" | jq -r '."begin-area".name')"
			artist_born="$(echo "$artist_data" | jq -r '."life-span".begin')"
			gender="$(echo "$artist_data" | jq -r ".gender")"
			matched_id=true
		else
			matched_id=false
			log "$setlog ERROR :: Cannot Find MusicBrainz Artist Match... :: SKIPPING"
			
			if [ ! -d "/config/logs/musicbrainz" ]; then
				mkdir -p "/config/logs/musicbrainz"
			fi
			touch "/config/logs/musicbrainz-$artist_id"
			return
		fi
	else
		if [ ! -f "/config/logs/musicbrainz-$artist_id" ]; then
			musicbrainz_main_artist_id="$(cat /config/cache/musicbrainz_$artist_id)"
			artist_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/artist/$musicbrainz_main_artist_id?fmt=json")
			artist_sort_name="$(echo "$artist_data" | jq -r '."sort-name"')"
			artist_formed="$(echo "$artist_data" | jq -r '."begin-area".name')"
			artist_born="$(echo "$artist_data" | jq -r '."life-span".begin')"
			gender="$(echo "$artist_data" | jq -r ".gender")"
			matched_id=true
		else
			log "$setlog ERROR :: Cannot Find MusicBrainz Artist Match... :: SKIPPING"
			matched_id=false
			return
		fi
	fi
	
	videos_data=$(curl -s "https://listen.tidal.com/v1/pages/data/d6bd1f7f-2f93-4136-87ba-aa35d01692ba?artistId=${artist_id}&offset=0&limit=50&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU")
	items_total=$(echo "$videos_data" | jq -r ".totalNumberOfItems")
	if [ $items_total -le 50 ]; then
		video_ids=$(echo "$videos_data" | jq -r ".items[].id")
	else
		if [ -f "/config/cache/${artist_id}-tidal-videos.json" ]; then
			video_ids=$(cat "/config/cache/${artist_id}-tidal-videos.json" | jq -r ".[].items[].id")
			videoidscount=$(echo "$video_ids" | wc -l)
			if [ $items_total != $videoidscount ]; then
				rm -rf /config/cache/${artist_id}-tidal-videos.json
			fi
		fi
		
		if [ ! -f "/config/cache/${artist_id}-tidal-videos.json" ]; then
			if [ ! -d "/config/temp" ]; then
				mkdir "/config/temp"
				sleep 0.1
			fi

			offsetcount=$(( $items_total / 50 ))
			for ((i=0;i<=$offsetcount;i++)); do
				if [ ! -f "release-page-$i.json" ]; then
					if [ $i != 0 ]; then
						offset=$(( $i * 50 ))
						dlnumber=$(( $offset + 50))
					else
						offset=0
						dlnumber=$(( $offset + 50))
					fi
					log "$artistnumber of $wantedtotal :: Tidal CACHE :: $LidArtistNameCap :: Downloading Releases page $i... ($offset - $dlnumber Results)"
					curl -s "https://listen.tidal.com/v1/pages/data/d6bd1f7f-2f93-4136-87ba-aa35d01692ba?artistId=${artist_id}&offset=$offset&limit=50&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU" -o "/config/temp/${artist_id}-releases-page-$i.json"
					sleep 0.1
				fi
			done


			if [ ! -f "/config/cache/${artist_id}-tidal-videos.json" ]; then
				jq -s '.' /config/temp/${artist_id}-releases-page-*.json > "/config/cache/${artist_id}-tidal-videos.json"
			fi

			if [ -f "/config/cache/${artist_id}-tidal-videos.json" ]; then
				rm /config/temp/${artist_id}-releases-page-*.json
				sleep .01
			fi

			if [ -d "/config/temp" ]; then
				sleep 0.1
				rm -rf "/config/temp"
			fi
		fi
		video_ids=$(cat "/config/cache/${artist_id}-tidal-videos.json" | jq -r ".[].items[].id")
		videos_data=$(cat "/config/cache/${artist_id}-tidal-videos.json" | jq -r ".[]")
	fi
	video_titles="$(echo "$videos_data" | jq -r ".items[].title")"
	
	
	albums_data=$(curl -s "https://listen.tidal.com/v1/pages/data/4b37c74b-f994-45dd-8fca-b7da2694da83?artistId=${artist_id}&offset=0&limit=50&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU")
	albums_total=$(echo "$albums_data" | jq -r ".totalNumberOfItems")
	if [ ! $albums_total == "null" ]; then
		if [ $albums_total -le 50 ]; then
			album_ids=$(echo "$albums_data" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
		else
			log "$setlog $DL_TYPE :: FINDING ALBUMS"
			if [ -f "/config/cache/${artist_id}-tidal-albums.json" ]; then
				album_ids=$(cat "/config/cache/${artist_id}-tidal-albums.json" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
				album_ids_count=$(echo "$album_ids" | wc -l)
				if [ $albums_total != $album_ids_count ]; then
					rm -rf /config/cache/${artist_id}-tidal-albums.json
				fi
			fi
			
			if [ ! -f "/config/cache/${artist_id}-tidal-albums.json" ]; then
				if [ ! -d "/config/temp" ]; then
					mkdir "/config/temp"
					sleep 0.1
				fi

				offsetcount=$(( $albums_total / 50 ))
				for ((i=0;i<=$offsetcount;i++)); do
					if [ ! -f "release-page-$i.json" ]; then
						if [ $i != 0 ]; then
							offset=$(( $i * 50 ))
							dlnumber=$(( $offset + 50))
						else
							offset=0
							dlnumber=$(( $offset + 50))
						fi
						log "$setlog $DL_TYPE :: FINDING ITEMS :: Downloading itemes page $i... ($offset - $dlnumber Results)"
						curl -s "https://listen.tidal.com/v1/pages/data/4b37c74b-f994-45dd-8fca-b7da2694da83?artistId=${artist_id}&offset=$offset&limit=50&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU" -o "/config/temp/${artist_id}-releases-page-$i.json"
						sleep 0.1
					fi
				done


				if [ ! -f "/config/cache/${artist_id}-tidal-albums.json" ]; then
					jq -s '.' /config/temp/${artist_id}-releases-page-*.json > "/config/cache/${artist_id}-tidal-albums.json"
				fi

				if [ -f "/config/cache/${artist_id}-tidal-albums.json" ]; then
					rm /config/temp/${artist_id}-releases-page-*.json
					sleep .01
				fi

				if [ -d "/config/temp" ]; then
					sleep 0.1
					rm -rf "/config/temp"
				fi
			fi
			album_ids=$(cat "/config/cache/${artist_id}-tidal-albums.json" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
			albums_data=$(cat "/config/cache/${artist_id}-tidal-albums.json" | jq -r ".[]")
			
		fi
		#echo "albums: $albums_total"
		album_ids=($(echo "$album_ids"))
	fi
	
	if [ "$albums_total" != "0" ]; then
		for id in ${!album_ids[@]}; do
			album_number=$(( $id + 1 ))
			album_total="$albums_total"
			album_id="${album_ids[$id]}"
			AlbumProcess $album_id
		done
	fi
	
	DL_TYPE="EP & SINGLES"
	
	single_ep_data=$(curl -s "https://listen.tidal.com/v1/pages/data/bb502cc2-58f7-4bd1-870a-265658fa36af?artistId=${artist_id}&offset=0&limit=50&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU")
	single_ep_total=$(echo "$single_ep_data" | jq -r ".totalNumberOfItems")
	if [ ! $single_ep_total == "null" ]; then
		if [ $single_ep_total -le 50 ]; then
			single_ep_ids=$(echo "$single_ep_data" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
		else
			log "$setlog $DL_TYPE :: FINDING ALBUMS"
			if [ -f "/config/cache/${artist_id}-tidal-single_ep_data.json" ]; then
				single_ep_ids=$(cat "/config/cache/${artist_id}-tidal-single_ep_data.json" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
				single_ep_ids_count=$(echo "$single_ep_ids" | wc -l)
				if [ $single_ep_total != $single_ep_ids_count ]; then
					rm -rf /config/cache/${artist_id}-tidal-single_ep_data.json
				fi
			fi
			
			if [ ! -f "/config/cache/${artist_id}-tidal-single_ep_data.json" ]; then
				if [ ! -d "/config/temp" ]; then
					mkdir "/config/temp"
					sleep 0.1
				fi

				offsetcount=$(( $single_ep_total / 50 ))
				for ((i=0;i<=$offsetcount;i++)); do
					if [ ! -f "release-page-$i.json" ]; then
						if [ $i != 0 ]; then
							offset=$(( $i * 50 ))
							dlnumber=$(( $offset + 50))
						else
							offset=0
							dlnumber=$(( $offset + 50))
						fi
						log "$setlog $DL_TYPE :: FINDING ITEMS :: Downloading itemes page $i... ($offset - $dlnumber Results)"
						curl -s "https://listen.tidal.com/v1/pages/data/bb502cc2-58f7-4bd1-870a-265658fa36af?artistId=${artist_id}&offset=$offset&limit=50&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU" -o "/config/temp/${artist_id}-releases-page-$i.json"
						sleep 0.1
					fi
				done


				if [ ! -f "/config/cache/${artist_id}-tidal-single_ep_data.json" ]; then
					jq -s '.' /config/temp/${artist_id}-releases-page-*.json > "/config/cache/${artist_id}-tidal-single_ep_data.json"
				fi

				if [ -f "/config/cache/${artist_id}-tidal-single_ep_data.json" ]; then
					rm /config/temp/${artist_id}-releases-page-*.json
					sleep .01
				fi

				if [ -d "/config/temp" ]; then
					sleep 0.1
					rm -rf "/config/temp"
				fi
			fi
			single_ep_ids=$(cat "/config/cache/${artist_id}-tidal-single_ep_data.json" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
			single_ep_data=$(cat "/config/cache/${artist_id}-tidal-single_ep_data.json" | jq -r ".[]")
			
		fi
		#echo "Single&EP: $single_ep_total"
		single_ep_ids=($(echo "$single_ep_ids"))
		
		if [ "$single_ep_total" != "0" ]; then
			for id in ${!single_ep_ids[@]}; do
				album_number=$(( $id + 1 ))
				album_total="$single_ep_total"
				album_id="${single_ep_ids[$id]}"
				AlbumProcess $album_id
			done
		fi
	fi
	
	compilations_data=$(curl -s "https://listen.tidal.com/v1/pages/data/9aee9d2e-3352-473e-b98e-4872e9e6c4c7?artistId=${artist_id}&offset=0&limit=50&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU")
	compilations_total=$(echo "$compilations_data" | jq -r ".totalNumberOfItems")
	# echo $compilations_data > comp_test.json
	
	DL_TYPE="COMPILATIONS"
	if [ ! $compilations_total == "null" ]; then
		if [ $compilations_total -le 50 ]; then
			compilations_ids=$(echo "$compilations_data" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
		else
			log "$setlog $DL_TYPE :: FINDING ALBUMS"
			if [ -f "/config/cache/${artist_id}-tidal-compilations_data.json" ]; then
				compilations_ids=$(cat "/config/cache/${artist_id}-tidal-compilations_data.json" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
				compilations_ids_count=$(echo "$compilations_ids" | wc -l)
				if [ $compilations_total != $compilations_ids_count ]; then
					rm -rf /config/cache/${artist_id}-tidal-compilations_data.json
				fi
			fi
			
			if [ ! -f "/config/cache/${artist_id}-tidal-compilations_data.json" ]; then
				if [ ! -d "/config/temp" ]; then
					mkdir "/config/temp"
					sleep 0.1
				fi

				offsetcount=$(( $compilations_total / 50 ))
				for ((i=0;i<=$offsetcount;i++)); do
					if [ ! -f "release-page-$i.json" ]; then
						if [ $i != 0 ]; then
							offset=$(( $i * 50 ))
							dlnumber=$(( $offset + 50))
						else
							offset=0
							dlnumber=$(( $offset + 50))
						fi
						log "$setlog $DL_TYPE :: FINDING ITEMS :: Downloading itemes page $i... ($offset - $dlnumber Results)"
						curl -s "https://listen.tidal.com/v1/pages/data/9aee9d2e-3352-473e-b98e-4872e9e6c4c7?artistId=${artist_id}&offset=$offset&limit=50&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU" -o "/config/temp/${artist_id}-releases-page-$i.json"
						sleep 0.1
					fi
				done


				if [ ! -f "/config/cache/${artist_id}-tidal-compilations_data.json" ]; then
					jq -s '.' /config/temp/${artist_id}-releases-page-*.json > "/config/cache/${artist_id}-tidal-compilations_data.json"
				fi

				if [ -f "/config/cache/${artist_id}-tidal-compilations_data.json" ]; then
					rm /config/temp/${artist_id}-releases-page-*.json
					sleep .01
				fi

				if [ -d "/config/temp" ]; then
					sleep 0.1
					rm -rf "/config/temp"
				fi
			fi
			compilations_ids=$(cat "/config/cache/${artist_id}-tidal-compilations_data.json" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
			compilations_data=$(cat "/config/cache/${artist_id}-tidal-compilations_data.json" | jq -r ".[]")
			
		fi
		#echo "compilations: $compilations_total"
		compilations_ids=($(echo "$compilations_ids"))
		if [ "$compilations_total" != "0" ]; then
			for id in ${!compilations_ids[@]}; do
				album_number=$(( $id + 1 ))
				album_id="${compilations_ids[$id]}"
				album_total="$compilations_total"
				compilation=true
				AlbumProcess $album_id
				compilation=false
			done
		fi
	fi
	
	live_data=$(curl -s "https://listen.tidal.com/v1/pages/data/81022451-77b3-4769-b611-5b29e34bb501?artistId=${artist_id}&offset=0&limit=50&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU")
	live_total=$(echo "$live_data" | jq -r ".totalNumberOfItems")
	DL_TYPE="LIVE"
	
	if [ ! $live_total == "null" ]; then
		if [ $live_total -le 50 ]; then
			live_ids=$(echo "$live_data" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
		else
			log "$setlog $DL_TYPE :: FINDING ALBUMS"
			if [ -f "/config/cache/${artist_id}-tidal-live_data.json" ]; then
				live_ids=$(cat "/config/cache/${artist_id}-tidal-live_data.json" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
				live_ids_count=$(echo "$live_ids" | wc -l)
				if [ $live_total != $live_ids_count ]; then
					echo "$live_total :: $live_ids_count"
					rm -rf /config/cache/${artist_id}-tidal-live_data.json
				fi
			fi
			
			if [ ! -f "/config/cache/${artist_id}-tidal-live_data.json" ]; then
				if [ ! -d "/config/temp" ]; then
					mkdir "/config/temp"
					sleep 0.1
				fi

				offsetcount=$(( $live_total / 50 ))
				for ((i=0;i<=$offsetcount;i++)); do
					if [ ! -f "release-page-$i.json" ]; then
						if [ $i != 0 ]; then
							offset=$(( $i * 50 ))
							dlnumber=$(( $offset + 50))
						else
							offset=0
							dlnumber=$(( $offset + 50))
						fi
						log "$setlog $DL_TYPE :: FINDING ITEMS :: Downloading itemes page $i... ($offset - $dlnumber Results)"
						curl -s "https://listen.tidal.com/v1/pages/data/5667e093-4bce-4f14-9292-bfdc20c9c3fe?artistId=${artist_id}&offset=$offset&limit=50&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU" -o "/config/temp/${artist_id}-releases-page-$i.json"
						sleep 0.1
					fi
				done


				if [ ! -f "/config/cache/${artist_id}-tidal-live_data.json" ]; then
					jq -s '.' /config/temp/${artist_id}-releases-page-*.json > "/config/cache/${artist_id}-tidal-live_data.json"
				fi

				if [ -f "/config/cache/${artist_id}-tidal-live_data.json" ]; then
					rm /config/temp/${artist_id}-releases-page-*.json
					sleep .01
				fi

				if [ -d "/config/temp" ]; then
					sleep 0.1
					rm -rf "/config/temp"
				fi
			fi
			live_ids=$(cat "/config/cache/${artist_id}-tidal-live_data.json" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
			live_data=$(cat "/config/cache/${artist_id}-tidal-live_data.json" | jq -r ".[]")
			
		fi
		#echo "live: $live_total"
		live_ids=($(echo "$live_ids"))
		if [ "$live_total" != "0" ]; then
			DL_TYPE="LIVE"
			for id in ${!live_ids[@]}; do
				album_number=$(( $id + 1 ))
				album_total="$live_total"
				album_id="${live_ids[$id]}"
				live=true
				AlbumProcess $album_id
				live=false
			done
		fi
	fi
	
	
	if [ $appears_on_enabled = false ]; then
		return
	fi
	
	appears_data=$(curl -s "https://listen.tidal.com/v1/pages/data/5667e093-4bce-4f14-9292-bfdc20c9c3fe?artistId=${artist_id}&offset=0&limit=50&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU")
	appears_total=$(echo "$appears_data" | jq -r ".totalNumberOfItems")
	DL_TYPE="APPEARS ON"
	if [ ! $appears_total == "null" ]; then
		if [ $appears_total -le 50 ]; then
			appears_ids=$(echo "$appears_data" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
		else
			log "$setlog $DL_TYPE :: FINDING ALBUMS"
			if [ -f "/config/cache/${artist_id}-tidal-appears_data.json" ]; then
				appears_ids=$(cat "/config/cache/${artist_id}-tidal-appears_data.json" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
				appears_ids_count=$(echo "$appears_ids" | wc -l)
				if [ $appears_total != $appears_ids_count ]; then
					echo "$appears_total :: $appears_ids_count"
					rm -rf /config/cache/${artist_id}-tidal-appears_data.json
				fi
			fi
			
			if [ ! -f "/config/cache/${artist_id}-tidal-appears_data.json" ]; then
				if [ ! -d "/config/temp" ]; then
					mkdir "/config/temp"
					sleep 0.1
				fi

				offsetcount=$(( $appears_total / 50 ))
				for ((i=0;i<=$offsetcount;i++)); do
					if [ ! -f "release-page-$i.json" ]; then
						if [ $i != 0 ]; then
							offset=$(( $i * 50 ))
							dlnumber=$(( $offset + 50))
						else
							offset=0
							dlnumber=$(( $offset + 50))
						fi
						log "$setlog $DL_TYPE :: FINDING ITEMS :: Downloading itemes page $i... ($offset - $dlnumber Results)"
						curl -s "https://listen.tidal.com/v1/pages/data/5667e093-4bce-4f14-9292-bfdc20c9c3fe?artistId=${artist_id}&offset=$offset&limit=50&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU" -o "/config/temp/${artist_id}-releases-page-$i.json"
						sleep 0.1
					fi
				done


				if [ ! -f "/config/cache/${artist_id}-tidal-appears_data.json" ]; then
					jq -s '.' /config/temp/${artist_id}-releases-page-*.json > "/config/cache/${artist_id}-tidal-appears_data.json"
				fi

				if [ -f "/config/cache/${artist_id}-tidal-appears_data.json" ]; then
					rm /config/temp/${artist_id}-releases-page-*.json
					sleep .01
				fi

				if [ -d "/config/temp" ]; then
					sleep 0.1
					rm -rf "/config/temp"
				fi
			fi
			appears_ids=$(cat "/config/cache/${artist_id}-tidal-appears_data.json" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
			appears_data=$(cat "/config/cache/${artist_id}-tidal-appears_data.json" | jq -r ".[]")
			
		fi
		#echo "appears: $appears_total"
		appears_ids=($(echo "$appears_ids"))
		if [ "$appears_total" != "0" ]; then
			for id in ${!appears_ids[@]}; do
				album_number=$(( $id + 1 ))
				album_total="$appears_total"
				album_id="${appears_ids[$id]}"
				AlbumProcess $album_id
			done
		fi
	fi

}


AlbumProcess () {
	albumlog="$setlog $DL_TYPE :: $album_number OF $album_total ::"
	if [ -d "$DownloadLocation/temp" ]; then
		rm -rf "$DownloadLocation/temp"
	fi
	
	if [ -f /config/logs/failed/$album_id ]; then
		log "$albumlog ERROR :: Previously Failed Download, skipping..."
		return
	fi
	
	if [ -d "$DownloadLocation/music" ]; then
		if find "$DownloadLocation/music" -type d -iname "* ($album_id)" | read; then
			log "$albumlog Already downloaded, skipping..."
			return
		fi
	fi
	
	deezer_track_album_id=""
	album_data=""
	album_data=$(curl -s "https://listen.tidal.com/v1/pages/album?albumId=$album_id&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU")
	album_data_info=$(echo "$album_data" | jq -r '.rows[].modules[] | select(.type=="ALBUM_HEADER")')
	album_title="$(echo "$album_data_info" | jq -r " .album.title")"
	album_title_clean="$(echo "$album_data_info" | jq -r " .album.title" | sed -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g'  -e "s/  */ /g")"
	album_version="$(echo "$album_data_info" | jq -r " .album.version")"
	if [ "$album_version" == "null" ]; then
		album_version=""
	elif echo "$album_title" | grep -i "$album_version" | read; then
		album_version=""
	else 
		album_version=" ($album_version)"
	fi
	album_version_clean="$(echo "$album_version" | sed -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g'  -e "s/  */ /g")"
	if [ "$compilation" = "true" ]; then
		album_type="COMPILATION"
	elif [ "$live" = "true" ]; then
		album_type="LIVE"
	else
		album_type="$(echo "$album_data_info" | jq -r " .album.type")"
	fi
	album_review="$(echo "$album_data_info" | jq -r " .review.text" | sed -e 's/\[[^][]*\]//g' | sed -e 's/<br\/>//g')"
	album_cover_id="$(echo "$album_data_info" | jq -r " .album.cover")"
	album_cover_id_fix=$(echo "$album_cover_id" | sed "s/-/\//g")
	album_cover_url=https://resources.tidal.com/images/$album_cover_id_fix/1280x1280.jpg
	album_copyright="$(echo "$album_data_info" | jq -r " .album.copyright")"
	album_release_date="$(echo "$album_data_info" | jq -r " .album.releaseDate")"
	album_release_year=${album_release_date:0:4}
	album_artist_name="$(echo "$album_data_info" | jq -r ".album.artists[].name" | head -n 1)"
	album_artist_id="$(echo "$album_data_info" | jq -r ".album.artists[].id" | head -n 1)"
	album_artist_name_clean="$(echo "$album_artist_name" | sed -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g'  -e "s/  */ /g")"
	album_folder_name="$album_artist_name_clean ($album_artist_id)/$album_artist_name_clean ($album_artist_id) - $album_type - $album_release_year - $album_title_clean${album_version_clean} ($album_id)"
	albumlog="$albumlog $album_title${album_version} ::"
	if [ "$album_artist_id" -ne "$artist_id" ]; then
		if [ "$album_artist_id" -ne "2935" ]; then
			log "$albumlog ERROR :: ARTIST :: $album_artist_name ($album_artist_id) :: Not Wanted :: Skipping..."
			return
		else
			log "$albumlog Varioud Artist Album Found :: Processing..."
		fi
	fi
	if [ -d "$DownloadLocation/music/$album_folder_name" ]; then
		log "$albumlog Already downloaded, skipping..."
		return
	fi
		
	if [ -d "$DownloadLocation/music" ]; then
		if find "$DownloadLocation/music" -type d -iname "$album_artist_name_clean ($album_artist_id) - $album_type - $album_release_year - $album_title_clean${album_version_clean} ([[[:digit:]][[:digit:]]*[[:digit:]][[:digit:]])" | read; then
			log "$albumlog Already downloaded, skipping..."
			return
		fi
	fi

	album_cred=$(curl -s "https://listen.tidal.com/v1/albums/$album_id/items/credits?replace=true&includeContributors=true&offset=0&limit=100&countryCode=US" -H 'x-tidal-token: CzET4vdadNUFQ5JU')
	album_cred_total=$(echo "$album_cred" | jq -r ".totalNumberOfItems")

	if [ "$album_cred_total" -gt "100" ]; then
		if [ ! -d "/config/temp" ]; then
			mkdir "/config/temp"
			sleep 0.1
		else
			rm -rf "/config/temp"
			mkdir "/config/temp"
			sleep 0.1
		fi
		offsetcount=$(( $album_cred_total / 100 ))
		for ((i=0;i<=$offsetcount;i++)); do
			if [ ! -f "release-page-$i.json" ]; then
				if [ $i != 0 ]; then
					offset=$(( $i * 100 ))
					dlnumber=$(( $offset + 100))
				else
					offset=0
					dlnumber=$(( $offset + 100))
				fi
				log "$albumlog Downloading itemes page $i... ($offset - $dlnumber Results)"
				curl -s "https://listen.tidal.com/v1/albums/$album_id/items/credits?replace=true&includeContributors=true&offset=$offset&limit=100&locale=en_US&deviceType=BROWSER&countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU" -o "/config/temp/${artist_id}-releases-page-$i.json"
				sleep 0.1
			fi
		done

		if [ ! -f "/config/cache/${artist_id}-tidal-$album_id-creds_data.json" ]; then
			jq -s '.' /config/temp/${artist_id}-releases-page-*.json > "/config/cache/${artist_id}-tidal-$album_id-creds_data.json"
		fi

		if [ -f "/config/cache/${artist_id}-tidal-$album_id-creds_data.json" ]; then
			rm /config/temp/${artist_id}-releases-page-*.json
			sleep .01
		fi

		if [ -d "/config/temp" ]; then
			sleep 0.1
			rm -rf "/config/temp"
		fi
		
		album_cred=$(cat "/config/cache/${artist_id}-tidal-$album_id-creds_data.json" | jq -r ".[]")
		rm "/config/cache/${artist_id}-tidal-$album_id-creds_data.json"
	fi
	
	#echo "$album_data" > album_data.json
	#echo "$album_cred" > album_cred.json
	
	
	#echo $album_title
	#echo $album_type
	#echo $album_cover_url
	#echo $album_review
	#echo $album_copyright
	#echo $album_release_date
	#echo $album_release_year
	#echo "$album_artist_name"
	
	#exit
	
	track_ids=$(echo "$album_data" | jq -r '.rows[].modules[] | select(.type=="ALBUM_ITEMS") | .pagedList.items[].item.id')
	track_ids_count=$(echo "$track_ids" | wc -l)
	track_ids=($(echo "$track_ids"))
	for id in ${!track_ids[@]}; do
		track_id_number=$(( $id + 1 ))
		track_id="${track_ids[$id]}"
		track_data=$(echo "$album_data" | jq -r ".rows[].modules[] | select(.type==\"ALBUM_ITEMS\") | .pagedList.items[].item | select(.id==$track_id)")
		track_credits=$(echo "$album_cred" | jq -r ".items[] | select(.item.id==$track_id)")
		#echo $track_credits
		track_title="$(echo "$track_data" | jq -r ".title")"
		track_title_clean="$(echo "$track_title" | sed -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g'  -e "s/  */ /g")"
		track_version="$(echo "$track_data" | jq -r ".version")"
		track_version_video="$(echo "$track_data" | jq -r ".version")"
		if [ "$track_version" == "null" ]; then
			track_version=""
		else
			track_version=" ($track_version)"
		fi
		track_version_clean="$(echo "$track_version" | sed -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g'  -e "s/  */ /g")"
		track_explicit="$(echo "$track_data" | jq -r ".explicit")"
		track_volume_number="$(echo "$track_data" | jq -r ".volumeNumber")"
		track_track_number="$(echo "$track_data" | jq -r ".trackNumber")"
		track_isrc=$(echo "$track_credits" | jq -r ".item.isrc")
		track_producer_ids=($(echo "$track_credits" | jq -r '.credits[] | select(.type=="Producer") | .contributors[].id'))
		track_composer_ids=($(echo "$track_credits" | jq -r '.credits[] | select(.type=="Composer") | .contributors[].id'))
		track_lyricist_ids=($(echo "$track_credits" | jq -r '.credits[] | select(.type=="Lyricist") | .contributors[].id'))
		track_mixer_ids=($(echo "$track_credits" | jq -r '.credits[] | select(.type=="Mixer") | .contributors[].id'))
		track_studio_ids=($(echo "$track_credits" | jq -r '.credits[] | select(.type=="Studio Personnel") | .contributors[].id'))
		track_artist_id=$(echo "$track_credits" | jq -r ".item.artist.id")
		track_artist_name=$(echo "$track_credits" | jq -r ".item.artist.name")
		track_artists_ids=($(echo "$track_credits" | jq -r ".item.artists[].id"))
				
		track_artists_names=()
		for id in ${!track_artists_ids[@]}; do
			subprocess=$(( $id + 1 ))
			track_artist_id=${track_artists_ids[$id]}
			track_artist_name="$(echo "$track_data" | jq -r ".artists[] | select(.id==$track_artist_id) | .name")"
			track_artist_type="$(echo "$track_data" | jq -r ".artists[] | select(.id==$track_artist_id) | .type")"
			track_artists_names+=("$track_artist_name")
			OUT=$OUT"$track_artist_name / "
			
			#echo $track_artist_name
			#echo $track_artist_type

		done
		track_artist_names="${OUT%???}"
		OUT=""
		nfo_track_artist_name="$(echo "$track_data" | jq -r ".artists[] | .name")"
		
		track_producer_names=()
		for id in ${!track_producer_ids[@]}; do
			subprocess=$(( $id + 1 ))
			track_producer_id=${track_producer_ids[$id]}
			track_producer_name="$(echo "$track_credits" | jq -r ".credits[] | select(.type==\"Producer\") | .contributors[] | select(.id==$track_producer_id) | .name")"
			track_producer_names+=("$track_producer_name")
			OUT=$OUT"$track_producer_name / "
			
			#echo $track_artist_name
			#echo $track_artist_type

		done
		track_producer_names="${OUT%???}"
		OUT=""
		
		track_composer_names=()
		for id in ${!track_composer_ids[@]}; do
			subprocess=$(( $id + 1 ))
			track_composer_id=${track_composer_ids[$id]}
			track_composer_name="$(echo "$track_credits" | jq -r ".credits[] | select(.type==\"Composer\") | .contributors[] | select(.id==$track_composer_id) | .name")"
			track_composer_names+=("$track_composer_name")
			OUT=$OUT"$track_composer_name / "
			
			#echo $track_artist_name
			#echo $track_artist_type

		done
		track_composer_names="${OUT%???}"
		OUT=""
		
		track_lyricist_names=()
		for id in ${!track_lyricist_ids[@]}; do
			subprocess=$(( $id + 1 ))
			track_lyricist_id=${track_lyricist_ids[$id]}
			track_lyricist_name="$(echo "$track_credits" | jq -r ".credits[] | select(.type==\"Lyricist\") | .contributors[] | select(.id==$track_lyricist_id) | .name")"
			track_lyricist_names+=("$track_lyricist_name")
			OUT=$OUT"$track_lyricist_name / "
			
			#echo $track_artist_name
			#echo $track_artist_type

		done
		track_lyricist_names="${OUT%???}"
		OUT=""
		
		track_mixer_names=()
		for id in ${!track_mixer_ids[@]}; do
			subprocess=$(( $id + 1 ))
			track_mixer_id=${track_mixer_ids[$id]}
			track_mixer_name="$(echo "$track_credits" | jq -r ".credits[] | select(.type==\"Mixer\") | .contributors[] | select(.id==$track_mixer_id) | .name")"
			track_mixer_names+=("$track_mixer_name")
			OUT=$OUT"$track_mixer_name / "
			
			#echo $track_artist_name
			#echo $track_artist_type

		done
		track_mixer_names="${OUT%???}"
		OUT=""
		
		track_studio_names=()
		for id in ${!track_studio_ids[@]}; do
			subprocess=$(( $id + 1 ))
			track_studio_id=${track_studio_ids[$id]}
			track_studio_name="$(echo "$track_credits" | jq -r ".credits[] | select(.type==\"Studio Personnel\") | .contributors[] | select(.id==$track_studio_id) | .name")"
			track_studio_names+=("$track_studio_name")
			OUT=$OUT"$track_studio_name / "
			
			#echo $track_artist_name
			#echo $track_artist_type

		done
		track_studio_names="${OUT%???}"
		OUT=""
		
		deezer_track_lyrics_text=""
		deezer_track_bpm="0"
		deezer_track_album_genres=""
		
		if [ -d "$DownloadLocation/Album" ]; then
            rm -rf "$DownloadLocation/Album"
        fi
		log "$albumlog $track_id_number OF $track_ids_count :: DOWNLOADING :: $track_id"
		tidal-dl -l "https://tidal.com/browse/track/$track_id" &>/dev/null
		
		if [ -d "$DownloadLocation/Album" ]; then
			if find $DownloadLocation/Album -type f -iname "*.m4a" | read; then
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
		
		#find $DownloadLocation/Album -type f -iname "*.m4a" -exec qtfaststart "{}" \; &>/dev/null
		file="$(find $DownloadLocation/Album -type f -iname "*.m4a")"
		filelyric="$(find $DownloadLocation/Album -type f -iname "*.lrc")"
		qtfaststart "$file" &>/dev/null
		track_track_number_padded=$(printf "%02d\n" $track_track_number)
		track_volume_number_padded=$(printf "%02d\n" $track_volume_number)
		#track_file_name="${track_volume_number_padded}${track_track_number_padded} - $track_title_clean${track_version_clean} ($track_id).m4a"
		track_file_name="${track_volume_number_padded}${track_track_number_padded} - $track_title_clean${track_version_clean}.m4a"
		track_file_lyric_name="${track_volume_number_padded}${track_track_number_padded} - $track_title_clean${track_version_clean}.lrc"
		video_file_name="$track_title_clean${track_version_clean}.mp4"
		track_video_file_name="${track_volume_number_padded}${track_track_number_padded} - $track_title_clean${track_version_clean}.mp4"
		mv "$file" "$DownloadLocation/Album/$track_file_name"
		if [ -f "$filelyric" ]; then
			mv "$filelyric" "$DownloadLocation/Album/$track_file_lyric_name"
		fi
		file="$DownloadLocation/Album/$track_file_name"
				
		if [ "$track_explicit" = "true" ];then
			track_explicit=1
		else
			track_explicit=0
		fi
		
		if [ "$album_artist_name" = "Various Artists" ]; then
			songcompilation="1"
		else
			songcompilation="0"
		fi
		python3 $SCRIPT_DIR/tag_music.py \
			--file "$file" \
			--songtitle "$track_title${track_version}" \
			--songalbum "$album_title${album_version}" \
			--songartist "$track_artist_names" \
			--songartistalbum "$album_artist_name" \
			--songcopyright "$album_copyright" \
			--songbpm "$deezer_track_bpm" \
			--songtracknumber "$track_track_number" \
			--songtracktotal "$track_ids_count" \
			--songdiscnumber "$track_volume_number" \
			--songcompilation "$songcompilation" \
			--songlyricrating "$track_explicit" \
			--songdate "$album_release_date" \
			--songyear "$album_release_year" \
			--songgenre "$deezer_track_album_genres" \
			--songcomposer "$track_composer_names" \
			--songisrc "$track_isrc" \
			--songauthor "$track_lyricist_names" \
			--songartists "$track_artist_names" \
			--songengineer "$track_studio_names" \
			--songproducer "$track_producer_names" \
			--songmixer "$track_mixer_names" \
			--songpublisher "$songpublisher" \
			--songlyrics "$deezer_track_lyrics_text" \
			--mbrainzalbumartistid "$musicbrainz_main_artist_id" \
			--songartwork "$DownloadLocation/Album/cover.jpg"
		log "$albumlog $track_id_number OF $track_ids_count :: OPTIMIZED for Streaming..."
		if [ ! -d "$DownloadLocation/temp" ]; then
			mkdir -p "$DownloadLocation/temp"
		fi
		
		
		
		if [ -d "$DownloadLocation/Album" ]; then
            find $DownloadLocation/Album -type f -exec mv "{}" "$DownloadLocation/temp/" \;
			rm -rf "$DownloadLocation/Album"
        fi
		
		
	done
	
	download_count=$(find $DownloadLocation/temp -type f -iname "*.m4a" | wc -l)
	albumlog="$setlog $DL_TYPE :: $album_number OF $album_total :: $album_title${album_version} ::"
	log "$albumlog Downloaded :: $download_count of $track_ids_count tracks"
	
	#find $DownloadLocation/Album -type f -iname "*.m4a" -exec mv "{}" $DownloadLocation/Album/ \; &>/dev/null
	
	if [ $download_count != $track_ids_count ]; then
		log "$albumlog :: ERROR :: Missing tracks... performing cleanup..."
		if [ ! -d "/config/logs/failed" ]; then
			mkdir -p "/config/logs/failed"
		fi
		touch /config/logs/failed/$album_id
		if [ -d "$DownloadLocation/temp" ]; then
			rm -rf "$DownloadLocation/temp"
		fi
		return
	fi
	
	if [ ! -d "$DownloadLocation/music/$album_folder_name" ]; then
		mkdir -p "$DownloadLocation/music/$album_folder_name"
	fi
	if [ -d "$DownloadLocation/temp" ]; then
		mv $DownloadLocation/temp/* "$DownloadLocation/music/$album_folder_name"/
	fi
	if [ -d "$DownloadLocation/temp" ]; then
		rm -rf "$DownloadLocation/temp"
	fi
	
	nfo="$DownloadLocation/music/$album_artist_name_clean ($album_artist_id)/artist.nfo"
	if [ ! -f "$nfo" ]; then
		log "$albumlog NFO WRITER :: Writing Artist NFO..."
		echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>" >> "$nfo"
		echo "<artist>" >> "$nfo"
		echo "	<name>${artist_name}</name>" >> "$nfo"
		if [ "$matched_id" == "true" ]; then
			echo "	<musicBrainzArtistID>$musicbrainz_main_artist_id</musicBrainzArtistID>" >> "$nfo"
			echo "	<sortname>$artist_sort_name</sortname> " >> "$nfo"
			echo "	<gender>$gender</gender>" >> "$nfo"
			echo "	<born>$artist_born</born>" >> "$nfo"
		else
			echo "	<musicBrainzArtistID/>" >> "$nfo"
		fi
		if [ "$artist_biography" = "null" ]; then
			echo "	<biography/>" >> "$nfo"
		else
			echo "	<biography>${artist_biography}</biography>" >> "$nfo"
		fi
		if [ "$artist_picture_id" == "null" ]; then
			echo "	<thumb/>" >> "$nfo"
		else
			curl -s "$thumb" -o "$DownloadLocation/music/$album_artist_name_clean ($album_artist_id)/poster.jpg"
			echo "	<thumb aspect=\"poster\" preview=\"poster.jpg\">poster.jpg</thumb>" >> "$nfo"
		fi
		echo "</artist>" >> "$nfo"
		tidy -w 2000 -i -m -xml "$nfo" &>/dev/null
		log "$albumlog NFO WRITER :: ARTIST NFO WRITTEN!"
	fi
	
	nfo="$DownloadLocation/music/$album_folder_name/album.nfo"
	if [ -d "$DownloadLocation/music/$album_folder_name" ]; then
		log "$albumlog NFO WRITER :: Writing Album NFO..."
		if [ ! -f "$nfo" ]; then
			echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>" >> "$nfo"
			echo "<album>" >> "$nfo"
			echo "	<title>$album_title${album_version}</title>" >> "$nfo"
			echo "	<userrating/>" >> "$nfo"
			echo "	<year>$album_release_year</year>" >> "$nfo"
			if [ "$album_review" = "null" ]; then
				echo "	<review/>" >> "$nfo"
			else
				echo "	<review>$album_review</review>" >> "$nfo"
			fi
			echo "	<albumArtistCredits>" >> "$nfo"
			echo "		<artist>$album_artist_name</artist>" >> "$nfo"
			echo "		<musicBrainzArtistID/>" >> "$nfo"
			echo "	</albumArtistCredits>" >> "$nfo"
			if [ -f "$DownloadLocation/music/$album_folder_name/cover.jpg" ]; then
				echo "	<thumb>cover.jpg</thumb>" >> "$nfo"
			else
				echo "	<thumb/>" >> "$nfo"
			fi
			echo "</album>" >> "$nfo"
			tidy -w 2000 -i -m -xml "$nfo" &>/dev/null
			log "$albumlog NFO WRITER :: ALBUM NFO WRITTEN!"
		fi
	fi
	
	
}

Configuration
LidarrConnection

log "############################################ SCRIPT COMPLETE"
if [ "$AutoStart" == "true" ]; then
	log "############################################ SCRIPT SLEEPING FOR $ScriptInterval"
fi
exit 0
