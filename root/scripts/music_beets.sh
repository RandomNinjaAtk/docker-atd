#!/usr/bin/with-contenv bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
agent="automated-tidal-downloader ( https://github.com/RandomNinjaAtk/docker-atd )"
DownloadLocation="/downloads-atd"
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source $SCRIPT_DIR/resources/streamrip.sh
source $SCRIPT_DIR/resources/musicbrainz.sh
source $SCRIPT_DIR/resources/media_processors.sh

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
	log "############# SCRIPT VERSION 1.0.0118"
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

	ClientConfigCheck
	MusicbrainzConfigurationValidation
	
	# verify downloads location
	if [ -d "/downloads-atd" ]; then
		log "$TITLESHORT: Download Location: $DownloadLocation"
	else
	    log "$TITLESHORT: ERROR: Download Location Not Found! (/downloads-atd)"
		log "$TITLESHORT: ERROR: To correct error, please add a \"$DownloadLocation\" volume"
		error=1
	fi

	SOURCE_CONNECTION="lidarr"

	if [ "$SOURCE_CONNECTION" == "lidarr" ]; then
		log "$TITLESHORT: Artist List Source: $SOURCE_CONNECTION"

		# Verify Lidarr Connectivity
		lidarrtest=$(curl -s "$LidarrUrl/api/v1/system/status?apikey=${LidarrApiKey}" | jq -r ".version")
		if [ ! -z "$lidarrtest" ]; then
			if [ "$lidarrtest" != "null" ]; then
				log "$TITLESHORT: Lidarr Connection Valid, version: $lidarrtest"
			else
				log "$TITLESHORT: ERROR: Cannot communicate with Lidarr, most likely a...."
				log "ERROR: Invalid API Key: $LidarrApiKey"
				error=1
			fi
		else
			log "$TITLESHORT: ERROR: Cannot communicate with Lidarr, no response"
			log "$TITLESHORT: ERROR: URL: $LidarrUrl"
			log "$TITLESHORT: ERROR: API Key: $LidarrApiKey"
			error=1
		fi
	fi

	if [ ! -z "$EnableReplayGain" ]; then
		if [ "$EnableReplayGain" == "true" ]; then
			log "$TITLESHORT: Replaygain Tagging: ENABLED"
		else
			log "$TITLESHORT: Replaygain Tagging: DISABLED"
		fi
	else
		log "$TITLESHORT: WARNING: EnableReplayGain setting invalid, defaulting to: false"
		EnableReplayGain="false"
	fi
	
	if [ ! -z "$CountryCode" ]; then
		log "$TITLESHORT: CountryCode: $CountryCode"
		CountryCode="${CountryCode^^}"
	else
		log "$TITLESHORT: WARNING: CountryCode not set, defaulting to: US"
		CountryCode="US"
	fi
	
	if [ ! -z "$Compilations" ]; then
		if [ "$Compilations" = "false" ]; then
			log "$TITLESHORT: Compilations: Disabled (Appears On)"
		else
			log "$TITLESHORT: Compilations: Enabled (Appears On)"
		fi
	else
		log "$TITLESHORT: WARNING: Compilations not set, defaulting to: Disabled (Appears On)"
		Compilations="false"
	fi
	
	if [ ! -z "$WantedQuality" ]; then
		if [ "$WantedQuality" = "MQA" ]; then
			log "$TITLESHORT: WARNING: WantedQuality: MQA (up to FLAC 24bit) not supported, defaulting to: FLAC"
			DownloadClientQuality=2
		elif [ "$WantedQuality" = "FLAC" ]; then
			log "$TITLESHORT: WantedQuality: FLAC 16bit"
			DownloadClientQuality=2
		elif [ "$WantedQuality" = "320" ]; then
			log "$TITLESHORT: WantedQuality: 320 kbps"
			DownloadClientQuality=1
		elif [ "$WantedQuality" = "128" ]; then
			log "$TITLESHORT: WantedQuality: 128 kbps"
			DownloadClientQuality=0
		fi
	else
		log "$TITLESHORT: WARNING: WantedQuality not set, defaulting to: FLAC"
		DownloadClientQuality=2
	fi
	
	
	if [ ! -z "$RequireQuality" ]; then
		if [ "$RequireQuality" = "false" ]; then
			log "$TITLESHORT: RequireQuality: Disabled"
		else
			log "$TITLESHORT: RequireQuality: Enabled"
		fi
	else
		log "$TITLESHORT: WARNING: RequireQuality not set, defaulting to: Disabled"
		RequireQuality="false"
	fi
	
	
	if [ ! -z "$FolderPermissions" ]; then
		log "$TITLESHORT: FolderPermissions: $FolderPermissions"
	else
		log "$TITLESHORT: WARNING: FolderPermissions not set, defaulting to: 777"
		FolderPermissions=777
	fi
	
	if [ ! -z "$FilePermisssions" ]; then
		log "$TITLESHORT: FilePermisssions: $FilePermisssions"
	else
		log "$TITLESHORT: WARNING: FilePermisssions not set, defaulting to: 666"
		FilePermisssions=666
	fi



	if [ $error = 1 ]; then
		log "Please correct errors before attempting to run script again..."
		log "Exiting..."
		exit 1
	fi
	sleep 5
	amount=1000000000
}

log () {
    m_time=`date "+%F %T"`
    echo $m_time" "$1
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
		artistname="$(echo "${artistdata}" | jq -r ".artistName")"
       		artistnamepath="$(echo "${artistdata}" | jq -r " .path")"
		artistfolder="$(basename "${artistnamepath}")"
		sanitizedartistname="$(basename "${artistnamepath}" | sed 's% (.*)$%%g')"
		tidalurl=""
		tidalartistid=""
		tidalurl=$(echo "${artistdata}" | jq -r ".links | .[] | select(.name==\"tidal\") | .url")
		tidalartistid="$(echo "$tidalurl" | grep -o '[[:digit:]]*' | head -n 1)"
      	if [ -z "$tidalurl" ]; then
			mbzartistinfo=$(curl -s -A "$agent" "${MusicbrainzMirror}/ws/2/artist/$mbid?inc=url-rels+genres&fmt=json")
			sleep 1
			tidalurl="$(echo "$mbzartistinfo" | jq -r ".relations | .[] | .url | select(.resource | contains(\"tidal\")) | .resource" | head -n 1)"
			tidalartistid="$(echo "$tidalurl" | grep -o '[[:digit:]]*')"
			if [ -z "$tidalurl" ]; then 
				mbzartistinfo=$(curl -s -A "$agent" "${MusicbrainzMirror}/ws/2/artist/$mbid?inc=url-rels+genres&fmt=json")
				tidalurl="$(echo "$mbzartistinfo" | jq -r ".relations | .[] | .url | select(.resource | contains(\"tidal\")) | .resource" | head -n 1)"
				tidalartistid="$(echo "$tidalurl" | grep -o '[[:digit:]]*' | head -n 1)"
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
		fi
		
        log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: Processing.."
		logheader="$artistnumber of $artisttotal"
		artist_id=$tidalartistid
		ProcessArtist
	done
}

LidarrList () {
	if [ -f "temp-lidarr-missing.json" ]; then
		rm "/scripts/temp-lidarr-missing.json"
	fi

	if [ -f "/scripts/temp-lidarr-cutoff.json" ]; then
		rm "/scripts/temp-lidarr-cutoff.json"
	fi

	if [ -f "/scripts/lidarr-monitored-list.json" ]; then
		rm "/scripts/lidarr-monitored-list.json"
	fi

	if [[ "$LIST" == "missing" || "$LIST" == "both" ]]; then
		log "Downloading missing list..."
		wget "$LidarrUrl/api/v1/wanted/missing?page=1&pagesize=${amount}&includeArtist=true&sortDir=desc&sortKey=releaseDate&apikey=${LidarrApiKey}" -O "/scripts/temp-lidarr-missing.json"
		missingtotal=$(cat "/scripts/temp-lidarr-missing.json" | jq -r '.records | .[] | .id' | wc -l)
		log "FINDING MISSING ALBUMS: ${missingtotal} Found"
	fi
	if [[ "$LIST" == "cutoff" || "$LIST" == "both" ]]; then
		log "Downloading cutoff list..."
		wget "$LidarrUrl/api/v1/wanted/cutoff?page=1&pagesize=${amount}&includeArtist=true&sortDir=desc&sortKey=releaseDate&apikey=${LidarrApiKey}" -O "/scripts/temp-lidarr-cutoff.json"
		cuttofftotal=$(cat "/scripts/temp-lidarr-cutoff.json" | jq -r '.records | .[] | .id' | wc -l)
		log "FINDING CUTOFF ALBUMS: ${cuttofftotal} Found"
	fi
	jq -s '.[]' /scripts/temp-lidarr-*.json > "/scripts/lidarr-monitored-list.json"
	missinglistalbumids=($(cat "/scripts/lidarr-monitored-list.json" | jq -r '.records | .[] | .id'))
	missinglisttotal=$(cat "/scripts/lidarr-monitored-list.json" | jq -r '.records | .[] | .id' | wc -l)
	if [ -f "/scripts/temp-lidarr-missing.json" ]; then
		rm "/scripts/temp-lidarr-missing.json"
	fi

	if [ -f "/scripts/temp-lidarr-cutoff.json" ]; then
		rm "/scripts/temp-lidarr-cutoff.json"
	fi

	if [ -f "/scripts/lidarr-monitored-list.json" ]; then
		rm "/scripts/lidarr-monitored-list.json"
	fi
}

beets () {
	echo ""
	trackcount=$(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
	echo "Matching $trackcount tracks with Beets"
	if [ -f /scripts/library.blb ]; then
		rm /scripts/library.blb
		sleep 0.1
		fi
	if [ -f /scripts/beets/beets.log ]; then 
		rm /scripts/beets.log
		sleep 0.1
	fi

	touch "/scripts/beets-match"
	sleep 0.1

	if [ $(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l) -gt 0 ]; then
		beet -c $SCRIPT_DIR/resources/beets-config.yaml -l /scripts/library.blb -d "$1" import -q "$1"
		if [ $(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -newer "/scripts/beets-match" | wc -l) -gt 0 ]; then
			echo "SUCCESS: Matched with beets!"
		else
			rm -rf "$1"/* 
			echo "ERROR: Unable to match using beets to a musicbrainz release, marking download as failed..."
			touch "/scripts/beets-match-error"
		fi	
	fi

	if [ -f "/scripts/beets-match" ]; then 
		rm "/scripts/beets-match"
		sleep 0.1
	fi
}




WantedMode () {
	echo "####### DOWNLOAD AUDIO (WANTED MODE)"
	LidarrList

	for id in ${!missinglistalbumids[@]}; do
		currentprocess=$(( $id + 1 ))
		lidarralbumid="${missinglistalbumids[$id]}"
		albumdeezerurl=""
		error=0
		lidarralbumdata=$(curl -s --header "X-Api-Key:"${LidarrApiKey} --request GET  "$LidarrUrl/api/v1/album?albumIds=${lidarralbumid}")
		OLDIFS="$IFS"
		IFS=$'\n'
		lidarralbumdrecordids=($(echo "${lidarralbumdata}" | jq -r '.[] | .releases | sort_by(.trackCount) | reverse | .[].foreignReleaseId'))
		IFS="$OLDIFS"
		albumreleasegroupmbzid=$(echo "${lidarralbumdata}"| jq -r '.[] | .foreignAlbumId')
		releases=$(curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/release?release-group=$albumreleasegroupmbzid&inc=url-rels&fmt=json")
		albumreleaseid=($(echo "${releases}"| jq -r '.releases[] | select(.relations[].url.resource | contains("deezer")) | .id'))
		sleep $MBRATELIMIT
		lidarralbumtype="$(echo "${lidarralbumdata}"| jq -r '.[] | .albumType')"
		lidarralbumtypelower="$(echo ${lidarralbumtype,,})"
		albumtitle="$(echo "${lidarralbumdata}"| jq -r '.[] | .title')"
		albumreleasedate="$(echo "${lidarralbumdata}"| jq -r '.[] | .releaseDate')"
		albumreleaseyear="${albumreleasedate:0:4}"
		albumclean="$(echo "$albumtitle" | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g")"
		albumartistmbzid=$(echo "${lidarralbumdata}"| jq -r '.[].artist.foreignArtistId')
		albumartistname=$(echo "${lidarralbumdata}"| jq -r '.[].artist.artistName')
		logheader="$currentprocess of $missinglisttotal :: $albumartistname :: $albumreleaseyear :: $lidarralbumtype :: $albumtitle"
		filelogheader="$albumartistname :: $albumreleaseyear :: $lidarralbumtype :: $albumtitle"
	done
		
}


ProcessArtist () {		
      
	
  
	DL_TYPE="ALBUMS"
	
	if [ -d "/config/temp" ]; then
		rm -rf "/config/temp"
		sleep 0.1
	fi
	
	if [ -f "/config/temp" ]; then
		rm "/config/temp"
		sleep 0.1
	fi

	if [ -f "/config/logs/musicbrainz-$artist_id" ]; then
		log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: ERROR :: Cannot Find MusicBrainz Artist Match... :: SKIPPING"
		return
	fi

	if [ -f "/config/logs/completed/artists/${artist_id}" ]; then
		log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: Artist previously archived... :: SKIPPING"
		return
	fi
	StartClientSelfTest="TEST"
	artist_data=$(curl -s "https://api.tidal.com/v1/artists/${artist_id}?countryCode=$CountryCode" -H 'x-tidal-token: CzET4vdadNUFQ5JU')
	artist_biography="$(curl -s "https://api.tidal.com/v1/artists/${artist_id}?countryCode=$CountryCode" -H 'x-tidal-token: CzET4vdadNUFQ5JU'| jq -r ".text" | sed -e 's/\[[^][]*\]//g' | sed -e 's/<br\/>/\n/g')"
	artist_picture_id="$(echo "$artist_data" | jq -r ".picture")"
	artist_name="$(echo "$artist_data" | jq -r ".name")"
	artist_picture_id_fix=$(echo "$artist_picture_id" | sed "s/-/\//g")
	thumb="https://resources.tidal.com/images/$artist_picture_id_fix/750x750.jpg"
	log "$logheader :: $artist_name"
	setlog="$artistnumber of $artisttotal :: $artist_name ::"
	
	musicbrainz_main_artist_id=$mbid
	artist_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/artist/$musicbrainz_main_artist_id?fmt=json")
	artist_sort_name="$(echo "$artist_data" | jq -r '."sort-name"')"
	artist_formed="$(echo "$artist_data" | jq -r '."begin-area".name')"
	artist_born="$(echo "$artist_data" | jq -r '."life-span".begin')"
	gender="$(echo "$artist_data" | jq -r ".gender")"
	matched_id=true
	

				
	albums_data=$(curl -s "https://api.tidal.com/v1/artists/${artist_id}/albums?countryCode=$CountryCode&offset=0&limit=50&filter=ALBUMS" -H "x-tidal-token: CzET4vdadNUFQ5JU")
	albums_total=$(echo "$albums_data" | jq -r ".totalNumberOfItems")
	if [ ! $albums_total == "null" ]; then
		if [ $albums_total -le 50 ]; then
			album_ids=$(echo "$albums_data" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
		else
			log "$setlog $DL_TYPE :: FINDING ALBUMS"
			
			
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
						curl -s "https://api.tidal.com/v1/artists/${artist_id}/albums?countryCode=$CountryCode&offset=$offset&limit=50&filter=ALBUMS" -H "x-tidal-token: CzET4vdadNUFQ5JU" -o "/config/temp/${artist_id}-releases-page-$i.json"
						sleep 0.1
					fi
				done

				ArtistAlbums=$(jq -s '.' /config/temp/${artist_id}-releases-page-*.json)

				if [ -d "/config/temp" ]; then
					rm /config/temp/${artist_id}-releases-page-*.json
					sleep 0.1
					rm -rf "/config/temp"
				fi
			album_ids=$(echo "$ArtistAlbums" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
			albums_data=$(echo "$ArtistAlbums" | jq -r ".[]")
			
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
	
	single_ep_data=$(curl -s "https://api.tidal.com/v1/artists/${artist_id}/albums?countryCode=$CountryCode&offset=0&limit=50&filter=EPSANDSINGLES" -H "x-tidal-token: CzET4vdadNUFQ5JU")
	single_ep_total=$(echo "$single_ep_data" | jq -r ".totalNumberOfItems")
	if [ ! $single_ep_total == "null" ]; then
		if [ $single_ep_total -le 50 ]; then
			single_ep_ids=$(echo "$single_ep_data" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
		else
			log "$setlog $DL_TYPE :: FINDING ALBUMS"
			
			
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
						curl -s "https://api.tidal.com/v1/artists/${artist_id}/albums?countryCode=$CountryCode&offset=$offset&limit=50&filter=EPSANDSINGLES" -H "x-tidal-token: CzET4vdadNUFQ5JU" -o "/config/temp/${artist_id}-releases-page-$i.json"
						sleep 0.1
					fi
				done

				ArtistSingleEP=$(jq -s '.' /config/temp/${artist_id}-releases-page-*.json)
	

	

				if [ -d "/config/temp" ]; then
					rm /config/temp/${artist_id}-releases-page-*.json
					sleep 0.1
					rm -rf "/config/temp"
				fi
			fi
			single_ep_ids=$(echo  "$ArtistSingleEP" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
			single_ep_data=$(echo "$ArtistSingleEP" | jq -r ".[]")
			
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
	
	if [ "$Compilations" = "true" ]; then
		
		compilations_data=$(curl -s "https://api.tidal.com/v1/artists/${artist_id}/albums?countryCode=$CountryCode&offset=0&limit=50&filter=COMPILATIONS" -H "x-tidal-token: CzET4vdadNUFQ5JU")
		compilations_total=$(echo "$compilations_data" | jq -r ".totalNumberOfItems")
		# echo $compilations_data > comp_test.json
		
		DL_TYPE="COMPILATIONS"
		if [ ! $compilations_total == "null" ]; then
			if [ $compilations_total -le 50 ]; then
				compilations_ids=$(echo "$compilations_data" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
			else
				log "$setlog $DL_TYPE :: FINDING ALBUMS"
				
				
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
							curl -s "https://api.tidal.com/v1/artists/${artist_id}/albums?countryCode=$CountryCode&offset=$offset&limit=50&filter=COMPILATIONS" -H "x-tidal-token: CzET4vdadNUFQ5JU" -o "/config/temp/${artist_id}-releases-page-$i.json"
							sleep 0.1
						fi
					done


					ArtistCompilations=$(jq -s '.' /config/temp/${artist_id}-releases-page-*.json)


					if [ -d "/config/temp" ]; then
						rm /config/temp/${artist_id}-releases-page-*.json
						sleep 0.1
						rm -rf "/config/temp"
					fi
				fi
				compilations_ids=$(echo "$ArtistCompilations" | jq -r ".[].items | sort_by(.numberOfTracks) | sort_by(.explicit and .numberOfTracks) | reverse |.[].id")
				compilations_data=$(echo "$ArtistCompilations" | jq -r ".[]")
				
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
	fi
	
	if [ ! -d /config/logs/completed/artists ]; then
		mkdir -p /config/logs/completed/artists
	fi

	log "$setlog Marking Artist Completed..."
	touch /config/logs/completed/artists/${artist_id}

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
	
	if [ -f "/config/logs/completed/albums/$album_id" ]; then	
		log "$albumlog Already downloaded, skipping..."
		return
	fi


	if [ -f "/config/logs/beets/matched/$album_id" ]; then	
		log "$albumlog Already downloaded and previously matched via beets, skipping..."
		return
	fi

	if [ -f "/config/logs/beets/unmatched/$album_id" ]; then	
		log "$albumlog Already downloaded and previously failed to beets match, skipping..."
		return
	fi

	
	deezer_track_album_id=""
	album_data=""
	album_data=$(curl -s "https://api.tidal.com/v1/albums/$album_id/?countryCode=$CountryCode" -H "x-tidal-token: CzET4vdadNUFQ5JU")
	album_title="$(echo "$album_data" | jq -r ".title")"
	album_title_clean="$(echo "$album_data" | jq -r ".title" | sed -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g'  -e "s/  */ /g")"
	album_version="$(echo "$album_data" | jq -r ".version")"
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
		MetadataAlbumType="COMPILATION"
	else
		album_type="$(echo "$album_data" | jq -r " .type")"
		MetadataAlbumType="$album_type"
	fi
	MetadataAlbumType="${MetadataAlbumType,,}"
	album_review=$(curl -s "https://api.tidal.com/v1/albums/$album_id/review?countryCode=US" -H "x-tidal-token: CzET4vdadNUFQ5JU")
	album_review="$(echo "$album_review" | jq -r ".text" | sed -e 's/\[[^][]*\]//g' | sed -e 's/<br\/>/\n/g')"
	album_cover_id="$(echo "$album_data" | jq -r ".cover")"
	album_cover_id_fix=$(echo "$album_cover_id" | sed "s/-/\//g")
	album_cover_url=https://resources.tidal.com/images/$album_cover_id_fix/1280x1280.jpg
	album_copyright="$(echo "$album_data" | jq -r ".copyright")"
	AlbumDuration="$(echo "$album_data" | jq -r ".duration")"
	album_release_date="$(echo "$album_data" | jq -r ".releaseDate")"
	album_release_year=${album_release_date:0:4}
	album_artist_name="$(echo "$album_data" | jq -r ".artists[].name" | head -n 1)"
	album_artist_id="$(echo "$album_data" | jq -r ".artists[].id" | head -n 1)"
	album_artist_name_clean="$(echo "$album_artist_name" | sed -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g'  -e "s/  */ /g")"
	album_artist_folder="$album_artist_name_clean ($album_artist_id)"
	album_folder_name="$album_artist_name_clean ($album_artist_id) - $album_type - $album_release_year - $album_title_clean${album_version_clean} ($album_id)"
	albumlog="$albumlog $album_type :: $album_title${album_version} ::"
	
	if [ -d "$DownloadLocation/music/$album_artist_folder/$album_folder_name" ]; then
		log "$albumlog Already downloaded, skipping..."
		if [ ! -d "/config/logs/completed/albums" ]; then
			mkdir -p "/config/logs/completed/albums"
		fi
		touch	/config/logs/completed/albums/$album_id
		return
	fi

	if echo "$album_data" | grep -i "DOLBY_ATMOS" | read; then
		log "$albumlog ERROR :: Album contains Dobly ATMOS tracks, skipping..."
		return
	fi

	if [ $album_artist_id -ne $artist_id ]; then
		if [ $album_artist_id -ne 2935 ]; then
			log "$albumlog ERROR :: ARTIST :: $album_artist_name ($album_artist_id) :: Not Wanted :: Skipping..."
			return
		else
			log "$albumlog Various Artist Album Found :: Processing..."
		fi
	fi
	
	if [ -d "$DownloadLocation/music/$album_artist_folder" ]; then
		if find "$DownloadLocation/music/$album_artist_folder" -type d -iname "$album_artist_name_clean ($album_artist_id) - $album_type - $album_release_year - $album_title_clean${album_version_clean} ([[[:digit:]][[:digit:]]*[[:digit:]][[:digit:]])" | read; then
			log "$albumlog Already downloaded, skipping..."
			return
		fi
	fi
	
	tempoffset=100
	album_tracks=$(curl -s "https://api.tidal.com/v1/albums/$album_id/items?limit=100&countryCode=$CountryCode" -H 'x-tidal-token: CzET4vdadNUFQ5JU')
	album_tracks_total=$(echo "$album_tracks" | jq -r ".totalNumberOfItems")

	if [ "$album_tracks_total" -gt "$tempoffset" ]; then
		if [ ! -d "/config/temp" ]; then
			mkdir "/config/temp"
			sleep 0.1
		else
			rm -rf "/config/temp"
			mkdir "/config/temp"
			sleep 0.1
		fi
		offsetcount=$(( $album_tracks_total / $tempoffset ))
		for ((i=0;i<=$offsetcount;i++)); do
			if [ ! -f "release-page-$i.json" ]; then
				if [ $i != 0 ]; then
					offset=$(( $i * $tempoffset ))
					dlnumber=$(( $offset + $tempoffset))
				else
					offset=0
					dlnumber=$(( $offset + $tempoffset))
				fi
				log "$albumlog Downloading itemes page $i... ($offset - $dlnumber Results)"
				curl -s "https://api.tidal.com/v1/albums/$album_id/items?&offset=$offset&limit=$tempoffset&countryCode=$CountryCode" -H "x-tidal-token: CzET4vdadNUFQ5JU" -o "/config/temp/${artist_id}-releases-page-$i.json"
				sleep 0.1
			fi
		done

		if [ ! -f "/config/cache/${artist_id}-tidal-$album_id-items_data.json" ]; then
			jq -s '.' /config/temp/${artist_id}-releases-page-*.json > "/config/cache/${artist_id}-tidal-$album_id-items_data.json"
		fi

		if [ -f "/config/cache/${artist_id}-tidal-$album_id-items_data.json" ]; then
			rm /config/temp/${artist_id}-releases-page-*.json
			sleep .01
		fi

		if [ -d "/config/temp" ]; then
			sleep 0.1
			rm -rf "/config/temp"
		fi
		
		album_items=$(cat "/config/cache/${artist_id}-tidal-$album_id-items_data.json" | jq -r ".[]")
		rm "/config/cache/${artist_id}-tidal-$album_id-items_data.json"
	else
		album_items=$(echo $album_tracks)
	fi

	if [ -d "$DownloadLocation/temp-complete" ]; then
       		rm -rf "$DownloadLocation/temp-complete"
   	fi
	
	ClientDownload "--max-quality $DownloadClientQuality https://tidal.com/browse/album/$album_id"
		
		if [ ! -d "$DownloadLocation/temp-complete" ]; then
			mkdir -p "$DownloadLocation/temp-complete"
		fi
		
		
		
		if [ -d "$DownloadLocation/temp" ]; then
            		find $DownloadLocation/temp -type f -exec mv "{}" "$DownloadLocation/temp-complete/" \;
			rm -rf "$DownloadLocation/temp"
      		fi
		
				
	if [ ! -d "$DownloadLocation/temp-complete" ]; then
		log "$albumlog ERROR :: Album Failed, moving on..."
		return
	fi

	download_count=$(find $DownloadLocation/temp-complete -type f -iname "*.m4a" -o -iname "*.flac" | wc -l)
	albumlog="$setlog $DL_TYPE :: $album_number OF $album_total :: $album_title${album_version} ::"
	log "$albumlog Downloaded :: $download_count of $track_ids_count tracks"
	
	#find $DownloadLocation/Album -type f -iname "*.m4a" -exec mv "{}" $DownloadLocation/Album/ \; &>/dev/null
	
	if [ $download_count != $track_ids_count ]; then
		log "$albumlog :: ERROR :: Missing tracks... performing cleanup..."
		if [ ! -d "/config/logs/failed" ]; then
			mkdir -p "/config/logs/failed"
		fi
		touch /config/logs/failed/$album_id
		if [ -d "$DownloadLocation/temp-complete" ]; then
			rm -rf "$DownloadLocation/temp-complete"
		fi
		return
	fi
	
	if [ ! -z "$album_genre" ]; then
		for file in "$DownloadLocation/temp-complete"/*.flac; do
			metaflac "$file" --set-tag=GENRE="$album_genre"
		done
	fi

	beets "$DownloadLocation/temp-complete"
	
	if [ -f "/scripts/beets-match-error" ]; then
		if [ ! -d "/config/logs/beets/unmatched" ]; then
			mkdir -p "/config/logs/beets/unmatched"
		fi
		log "$albumlog :: ERROR :: Beets could not match album, skipping..."
		touch "/config/logs/beets/unmatched/$album_id"
		rm "/scripts/beets-match-error"
		return
	else
		log "$albumlog :: BEETS MATCH FOUND!"
	fi
	
	GetFile=$(find "$DownloadLocation/temp-complete" -type f -iname "*.flac" | head -n1)
	AlbumMusicbrainzReleaseGroupId=$(python3 /storage/media/music/mbrainz_id.py "$GetFile" | grep MUSICBRAINZ_RELEASEGROUPID | cut -d = -f 2)
	echo "$AlbumMusicbrainzReleaseGroupId"

	LidarrAlbumData=$(curl -s --header "X-Api-Key:"${LidarrApiKey} --request GET  "$LidarrUrl/api/v1/album/" | jq -r ".[]")

	lidarrPercentOfTracks=$(echo "$LidarrAlbumData" | jq -r "select(.foreignAlbumId==\"$AlbumMusicbrainzReleaseGroupId\") | .statistics.percentOfTracks")
	if [ "$lidarrPercentOfTracks" = "null" ]; then
    	lidarrPercentOfTracks=0
	fi
	if [ $lidarrPercentOfTracks -gt 0 ]; then
    	log "$albumlog :: ERROR :: Already Imported"
		if [ -d "$DownloadLocation/temp-complete" ]; then
			rm -rf "$DownloadLocation/temp-complete"
		fi
		touch "/config/logs/beets/matched/$album_id"
		return
	fi
	
	
	AddReplaygainTags

	TidalAlbumTitleClean="$(echo "$album_title" | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g")"
			artistclean="$(echo "$album_artist_name" | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g")"
			if [ ! -d "$DownloadLocation/for_import/$artistclean - $TidalAlbumTitleClean ($albumreleaseyear)-WEB-$MetadataAlbumType-streamrip" ]; then
				albumbimportfolder="$DownloadLocation/for_import/$artistclean - $TidalAlbumTitleClean ($album_release_year)-WEB-$MetadataAlbumType-streamrip"
				mkdir -p "$DownloadLocation/for_import/$artistclean - $TidalAlbumTitleClean ($album_release_year)-WEB-$MetadataAlbumType-streamrip"
				find $DownloadLocation/temp-complete -type f -exec mv {} "$DownloadLocation/for_import/$artistclean - $TidalAlbumTitleClean ($album_release_year)-WEB-$MetadataAlbumType-streamrip"/ \;
				if [ -d "$DownloadLocation/temp-complete" ]; then
					rm -rf "$DownloadLocation/temp-complete"
				fi
				chmod 777 -R "$albumbimportfolder"
				LidarrProcessIt=$(curl -s "$LidarrUrl/api/v1/command" --header "X-Api-Key:"${LidarrApiKey} -H "Content-Type: application/json" --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"${albumbimportfolder}\"}")
				log "$albumlog :: LIDARR IMPORT NOTIFICATION SENT! :: $albumbimportfolder"
				
				if [ ! -d "/config/logs/beets/matched" ]; then
					mkdir -p "/config/logs/beets/matched"
				fi
				touch "/config/logs/beets/matched/$album_id"
				rm /tmp/*.jpg
			fi
	return
	#echo "$LidarrAlbumData" | jq -r ".foreignAlbumId"
	echo "$LidarrAlbumData" | jq -r ". | select(.foreignAlbumId==$AlbumMusicbrainzReleaseGroupId)"
	exit
	echo "$LidarrAlbumData" | jq -r ".statistics.sizeOnDisk"
	
	exit
	AddReplaygainTags

	if [ ! -d "$DownloadLocation/music" ]; then
		mkdir -p "$DownloadLocation/music"
		chmod $FolderPermissions "$DownloadLocation/music"
	fi
	if [ ! -d "$DownloadLocation/music/$album_artist_folder" ]; then
		mkdir -p "$DownloadLocation/music/$album_artist_folder"
		chmod $FolderPermissions "$DownloadLocation/music/$album_artist_folder"
	fi
	if [ ! -d "$DownloadLocation/music/$album_artist_folder/$album_folder_name" ]; then
		mkdir -p "$DownloadLocation/music/$album_artist_folder/$album_folder_name"
		chmod $FolderPermissions "$DownloadLocation/music/$album_artist_folder/$album_folder_name"
	fi
	if [ -d "$DownloadLocation/temp-complete" ]; then
		mv $DownloadLocation/temp-complete/* "$DownloadLocation/music/$album_artist_folder/$album_folder_name"/
		chmod $FilePermisssions "$DownloadLocation/music/$album_artist_folder/$album_folder_name"/*
	fi
	if [ -d "$DownloadLocation/temp-complete" ]; then
		rm -rf "$DownloadLocation/temp-complete"
	fi
	if [ -d "$DownloadLocation/temp" ]; then
		rm -rf "$DownloadLocation/temp"
	fi
	
	nfo="$DownloadLocation/music/$album_artist_folder/artist.nfo"
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
			curl -s "$thumb" -o "$DownloadLocation/music/$album_artist_folder/poster.jpg"
			chmod $FilePermisssions "$DownloadLocation/music/$album_artist_folder/poster.jpg"
			echo "	<thumb aspect=\"poster\" preview=\"poster.jpg\">poster.jpg</thumb>" >> "$nfo"
		fi
		echo "</artist>" >> "$nfo"
		tidy -w 2000 -i -m -xml "$nfo" &>/dev/null
		chmod $FilePermisssions "$nfo"
		log "$albumlog NFO WRITER :: ARTIST NFO WRITTEN!"
	fi
	
	nfo="$DownloadLocation/music/$album_artist_folder/$album_folder_name/album.nfo"
	if [ -d "$DownloadLocation/music/$album_artist_folder/$album_folder_name" ]; then
		log "$albumlog NFO WRITER :: Writing Album NFO..."
		if [ ! -f "$nfo" ]; then
			echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>" >> "$nfo"
			echo "<album>" >> "$nfo"
			echo "	<title>$album_title${album_version}</title>" >> "$nfo"
			echo "	<userrating/>" >> "$nfo"
			echo "	<year>$album_release_year</year>" >> "$nfo"
			if [ ! -z "$album_genre" ]; then
				echo "	<genre>$album_genre</genre>" >> "$nfo"			
			fi
			if [ "$album_review" = "null" ]; then
				echo "	<review/>" >> "$nfo"
			else
				echo "	<review>$album_review</review>" >> "$nfo"
			fi
			echo "	<type>${MetadataAlbumType^}</type>" >> "$nfo"
			if [ "$compilation" = "true" ]; then
				echo "	<compilation>true</compilation>" >> "$nfo"
			else
				echo "	<compilation>false</compilation>" >> "$nfo"
			fi
			echo "	<duration>$AlbumDuration</duration>" >> "$nfo"
			echo "	<albumArtistCredits>" >> "$nfo"
			echo "		<artist>$album_artist_name</artist>" >> "$nfo"
			if [ "$matched_id" == "true" ]; then
				echo "		<musicBrainzArtistID>$musicbrainz_main_artist_id</musicBrainzArtistID>" >> "$nfo"
			else
				echo "		<musicBrainzArtistID/>" >> "$nfo"
			fi
			echo "	</albumArtistCredits>" >> "$nfo"
			if [ -f "$DownloadLocation/music/$album_artist_folder/$album_folder_name/cover.jpg" ]; then
				echo "	<thumb>cover.jpg</thumb>" >> "$nfo"
			else
				echo "	<thumb/>" >> "$nfo"
			fi
			echo "</album>" >> "$nfo"
			tidy -w 2000 -i -m -xml "$nfo" &>/dev/null
			chmod $FilePermisssions "$nfo"
			log "$albumlog NFO WRITER :: ALBUM NFO WRITTEN!"
		fi
	fi
	
}

Configuration

if [ "$DownloadMode" = "wanted" ]; then
	LidarrList
	WantedMode
else
	LidarrConnection
fi

log "############################################ SCRIPT COMPLETE"
if [ "$AutoStart" == "true" ]; then
	log "############################################ SCRIPT SLEEPING FOR $ScriptInterval"
fi
exit 0
