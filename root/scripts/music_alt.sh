#!/usr/bin/with-contenv bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
agent="automated-tidal-downloader ( https://github.com/RandomNinjaAtk/docker-atd )"
DownloadLocation="/downloads-atd"
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

Configuration () {
	functionName=Configuration
	processstartid="$(ps -A -o pid,cmd|grep "start.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	processdownloadid="$(ps -A -o pid,cmd|grep "download.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	log "To kill script, use the following command:"
	log "kill -9 $processstartid"
	log "kill -9 $processdownloadid"
	log ""
	log ""
	sleep 2
	log "############# $TITLE"
	log "############# SCRIPT VERSION 1.0.0"
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
	
	if [ ! -z "$CountryCode" ]; then
		log "$TITLESHORT: CountryCode: $CountryCode"
		CountryCode="${CountryCode^^}"
	else
		log "$TITLESHORT: WARNING: CountryCode not set, defaulting to: US"
		CountryCode="US"
	fi

    if [ ! -f /root/.tidal-dl.json ]; then
    	log "TIDAL :: No default config found, importing default config \"tidal.json\""
    	if [ -f $SCRIPT_DIR/tidal-dl.json ]; then
    		cp $SCRIPT_DIR/tidal-dl.json /root/.tidal-dl.json
    		chmod 777 -R /root
    	fi
    	tidal-dl -o /tmp
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
    echo $m_time" :: $functionName :: "$1
}

GetLidarrArtistList () {
	# Function get list of Lidarr Artists
	functionName=GetLidarrArtistList
	log "Start"
	lidarrArtistsData=$(curl -s --header "X-Api-Key:"${LidarrApiKey} --request GET  "$LidarrUrl/api/v1/Artist/")
	lidarrArtistTotal=$(echo "${lidarrArtistsData}"| jq -r '.[].sortName' | wc -l)
	lidarrList=($(echo "${lidarrArtistsData}" | jq -r ".[].foreignArtistId"))
	log "$lidarrArtistTotal Artists Found"
	log "End"
}

ProcessLidarrArtistList () {
	functionName=ProcessLidarrArtistList
	log "Start"
	for id in ${!lidarrList[@]}; do
		artistNumber=$(( $id + 1 ))
		musicbrainzId="${lidarrList[$id]}"
		lidarrArtistData=$(echo "${lidarrArtistsData}" | jq -r ".[] | select(.foreignArtistId==\"${musicbrainzId}\")")
		lidarrArtistName="$(echo "${lidarrArtistData}" | jq -r " .artistName")"
        lidarrArtistPath="$(echo "${lidarrArtistData}" | jq -r " .path")"
		lidarrArtistFolder="$(basename "${lidarrArtistPath}")"
		lidarrArtistNameSanitized="$(basename "${lidarrArtistPath}" | sed 's% (.*)$%%g')"
		OLDIFS="$IFS"
		IFS=$'\n'
		lidarrArtistGenres=($(echo "${lidarrArtistData}" | jq -r " .genres | .[]"))
		IFS="$OLDIFS"
		position="$artistNumber of $lidarrArtistTotal :: $lidarrArtistName"
		log "$position :: Start"
		GetTidalUrl
		GetTidalArtistData
		GetTidalArtistAlbums
		functionName=ProcessLidarrArtistList
		log "$position :: End"
	done
	log "End"
}

GetTidalUrl () {
	functionName=GetTidalUrl
	log "$position :: Start"
	tidalArtistUrl="" # Reset
	tidalArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"tidal\") | .url")
	tidalArtistId="$(echo "$tidalArtistUrl" | grep -o '[[:digit:]]*' | sort -u)"

	if [ -z "$tidalArtistUrl" ]; then 
        mbzArtistInfo=$(curl -s -A "$agent" "${MusicbrainzMirror}/ws/2/artist/$musicbrainzId?inc=url-rels+genres&fmt=json")
        tidalArtistUrl="$(echo "$mbzArtistInfo" | jq -r ".relations | .[] | .url | select(.resource | contains(\"tidal\")) | .resource" | head -n 1)"
        tidalArtistId="$(echo "$tidalArtistUrl" | grep -o '[[:digit:]]*' | sort -u)"
        sleep 1.5
    fi
    if [ -z "$tidalArtistUrl" ]; then 
        log "$position :: TIDAL :: ERROR :: musicbrainz id: $musicbrainzId is missing Tidal link, see: \"/config/logs/error/$lidarrArtistNameSanitized.log\" for more detail..."
        if [ ! -d /config/logs/error ]; then
            mkdir -p /config/logs/error
        fi
        if [ ! -f "/config/logs/error/$lidarrArtistNameSanitized.log" ]; then          
            echo "$position :: Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$musicbrainzId/relationships for \"${lidarrArtistName}\" with Tidal Artist Link" >> "/config/logs/error/$lidarrArtistNameSanitized.log"
        fi
        return
    fi
    if [ -f "/config/logs/error/$lidarrArtistNameSanitized.log" ]; then        
        rm "/config/logs/error/$lidarrArtistNameSanitized.log"
    fi
	log "$position :: Artist Found :: ID :: $tidalArtistId"
	log "$position :: End"
}

GetTidalArtistData () {
	functionName=GetTidalArtistData
	log "$position :: Start"
	log "$position :: $tidalArtistId"
	tidalArtistData=$(curl -s "https://api.tidal.com/v1/artists/${tidalArtistId}?countryCode=$CountryCode" -H 'x-tidal-token: CzET4vdadNUFQ5JU')
	tidalArtistBiography="$(echo "$tidalArtistData" | jq -r ".text" | sed -e 's/\[[^][]*\]//g' | sed -e 's/<br\/>/\n/g')"
	tidalArtistName="$(echo "$tidalArtistData" | jq -r ".name")"
	tidalArtistPictureId="$(echo "$tidalArtistData" | jq -r ".picture")"
	tidalArtistPictureIdFix=$(echo "$tidalArtistPictureId" | sed "s/-/\//g")
	tidalArtistPictureThumb="https://resources.tidal.com/images/$tidalArtistPictureIdFix/750x750.jpg"
	log "$position :: Tidal :: $tidalArtistName"
	log "$position :: $tidalArtistBiography"
	log "$position :: $tidalArtistPictureThumb"
	log "$position :: End"
}

GetTidalArtistAlbums () {
	functionName=GetTidalArtistAlbums
	log "$position :: Start"
	tidalArtistAlbumsData=$(curl -s "https://api.tidal.com/v1/artists/${tidalArtistId}/albums?limit=1000&countryCode=$CountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU')
	tidalArtistAlbumsIds=$(echo "$tidalArtistAlbumsData" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse | .[].id")
	tidalArtistAlbumsIdsCount=$(echo "$tidalArtistAlbumsIds" | wc -l)
	tidalArtistAlbumsNumberOfItems=$(echo "$tidalArtistAlbumsData" | jq -r ".totalNumberOfItems")
	log "$position :: $tidalArtistAlbumsNumberOfItems of $tidalArtistAlbumsIdsCount :: Albums Found"
	compilation=false
	ProcessTidalIdList "$tidalArtistAlbumsIds"
	functionName=GetTidalArtistAlbums
	tidalArtistAlbumsDataCompilation=$(curl -s "https://api.tidal.com/v1/artists/${tidalArtistId}/albums?limit=1000&countryCode=$CountryCode&filter=COMPILATIONS" -H 'x-tidal-token: CzET4vdadNUFQ5JU')
	tidalArtistAlbumsIdsCompilation=$(echo "$tidalArtistAlbumsDataCompilation" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse | .[].id")
	tidalArtistAlbumsIdsCountCompilation=$(echo "$tidalArtistAlbumsIdsCompilation" | wc -l)
	tidalArtistAlbumsNumberOfItemsCompilation=$(echo "$tidalArtistAlbumsDataCompilation" | jq -r ".totalNumberOfItems")
	log "$position :: $tidalArtistAlbumsNumberOfItemsCompilation of $tidalArtistAlbumsIdsCountCompilation :: Compilations Found"
	compilation=true
	#ProcessTidalIdList "$tidalArtistAlbumsIdsCompilation"
	functionName=GetTidalArtistAlbums
	log "$position :: End"
}

ProcessTidalIdList () {
	functionName=ProcessTidalIdList
	log "$position :: Start"
	idListCount=$(echo "$1" | wc -l)
	idList=($(echo $1))
	for id in ${!idList[@]}; do
		idNumber=$(( $id + 1 ))
		tidalId="${idList[$id]}"
		log "$position :: $idNumber of $idListCount :: $tidalId :: Start"
		tidalAlbumData=$(curl -s "https://api.tidal.com/v1/albums/$tidalId/?countryCode=$CountryCode" -H "x-tidal-token: CzET4vdadNUFQ5JU")
		tidalAlbumTitle=$(echo $tidalAlbumData | jq -r '.title')
		tidalAlbumTitleSanitized=$(echo $tidalAlbumTitle | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
		tidalAlbumReleaseDate=$(echo $tidalAlbumData | jq -r '.releaseDate')
		if [ "$tidalAlbumReleaseDate" = "null" ]; then
			tidalAlbumReleaseDate=$(echo $tidalAlbumData | jq -r '.streamStartDate')
		fi
		tidalAlbumReleaseYear=${tidalAlbumReleaseDate:0:4}
		tidalAlbumType=$(echo $tidalAlbumData | jq -r '.type')
		tidalAlbumNumberOfTracks=$(echo $tidalAlbumData | jq -r '.numberOfTracks')
		tidalAlbumNumberOfVolumes=$(echo $tidalAlbumData | jq -r '.numberOfVolumes')
		tidalAlbumCopyright=$(echo $tidalAlbumData | jq -r '.copyright')
		tidalAlbumUpc=$(echo $tidalAlbumData | jq -r '.upc')
		tidalAlbumArtist=$(echo $tidalAlbumData | jq -r '.artist.name')
		tidalAlbumArtistId=$(echo $tidalAlbumData | jq -r '.artist.id')

		if [ $tidalAlbumArtistId -ne $tidalArtistId ]; then
			log "$position :: $idNumber of $idListCount :: $tidalId :: $tidalAlbumArtistId -ne $tidalId :: skipping..."
			continue
		fi
		tidalAlbumAudioModes=$(echo $tidalAlbumData | jq -r '.audioModes')
		if echo "$tidalAlbumAudioModes" | grep "DOLBY_ATMOS" | read; then
			log "$position :: $idNumber of $idListCount :: $tidalId :: $tidalAlbumFoldername :: DOLBY ATMOS :: skipping..."
			continue
		fi
		tidalAlbumArtistSanitized=$(echo $tidalAlbumArtist | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
		tidalAlbumFoldername="$tidalAlbumArtistSanitized - $tidalAlbumTitleSanitized ($tidalAlbumReleaseYear)-WEB-$tidalAlbumType-atd"
		if [ -d "$lidarrArtistPath/$tidalAlbumFoldername" ]; then
			log "$position :: $idNumber of $idListCount :: $tidalId :: $tidalAlbumFoldername :: Previously Downloaded :: skipping..."
			continue
		fi
		if [ -f "/config/logs/beets/matched/$tidalId" ]; then
			log "$position :: $idNumber of $idListCount :: $tidalId :: $tidalAlbumFoldername :: Previously Downloaded :: skipping..."
			continue
		fi
		deezerAlbumGenre=""
		tidalAlbumTracks=$(curl -s "https://api.tidal.com/v1/albums/$tidalId/items?limit=100&countryCode=$CountryCode" -H "x-tidal-token: CzET4vdadNUFQ5JU")
		tidalAlbumTrackIds=$(echo $tidalAlbumTracks | jq -r '.items[].item.id')
		tidalAlbumTracksCount=$(echo "$tidalAlbumTrackIds" | wc -l)
		tidalAlbumTrackIds=($(echo $tidalAlbumTrackIds))
		for id in ${!tidalAlbumTrackIds[@]}; do
			idTrackNumber=$(( $id + 1 ))
			tidalTrackId="${tidalAlbumTrackIds[$id]}"
			log "$position :: $idNumber of $idListCount :: $tidalId :: $idTrackNumber of $tidalAlbumTracksCount :: $tidalTrackId"
			tidalTrackData=$(echo $tidalAlbumTracks | jq -r ".items[].item | select(.id==$tidalTrackId)")
			tidalTrackCredits=$(curl -s "https://api.tidal.com/v1/tracks/$tidalTrackId/contributors?limit=1000&countryCode=$CountryCode" -H 'x-tidal-token: CzET4vdadNUFQ5JU')
			tidalTrackTitle=$(echo $tidalTrackData | jq -r ".title")
			tidalTrackTitleSanitized=$(echo $tidalTrackTitle | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
			tidalTrackNumber=$(echo $tidalTrackData | jq -r ".trackNumber")
			tidalTrackCopyright=$(echo "$tidalTrackData" | jq -r ".copyright")
			tidalTrackIsrc=$(echo "$tidalTrackData" | jq -r ".isrc")
			tidalTrackExplicit="$(echo "$tidalTrackData" | jq -r ".explicit")"

			if [ -z "$deezerAlbumGenre" ]; then
				track_deezer_data=""
				deezer_album_id=""
				track_deezer_data=$(curl -s "https://api.deezer.com/2.0/track/isrc:$tidalTrackIsrc")
				if echo $track_deezer_data | grep "error" | read; then
					deezerAlbumGenre=""
				else
					deezer_album_id=$(echo $track_deezer_data | jq -r .album.id)
					deezer_album_data=$(curl -s "https://api.deezer.com/2.0/album/$deezer_album_id")
					album_deezer_genre="$(echo $deezer_album_data | jq -r ".genres.data[].name" | head -n 1)"
					deezerAlbumGenre="${album_deezer_genre,,}"
				fi
			fi

			tidalTrackArtistsIds=($(echo "$tidalTrackData" | jq -r ".artists[].id"))
			if [ $tidalTrackNumber -lt 10 ]; then
				tidalTrackNumber="0$tidalTrackNumber"
			fi
			tidalTrackVolume=$(echo $tidalTrackData | jq -r ".volumeNumber")
			if [ $tidalTrackVolume -lt 10 ]; then
				tidalTrackVolume="0$tidalTrackVolume"
			fi

			DownloadTidalId "https://tidal.com/browse/track/$tidalTrackId"
			find /tmp -type f -iname "$tidalTrackNumber.flac" -exec mv {} "/tmp/atd/${tidalTrackVolume}${tidalTrackNumber} - $tidalTrackTitleSanitized.flac" \;
			find /tmp -type f -iname "$tidalTrackNumber.m4a" -exec mv {} "/tmp/atd/${tidalTrackVolume}${tidalTrackNumber} - $tidalTrackTitleSanitized.m4a" \;
			find /tmp -type f -iname "$tidalTrackNumber.lrc" -exec mv {} "/tmp/atd/${tidalTrackVolume}${tidalTrackNumber} - $tidalTrackTitleSanitized.lrc" \;

			file="/tmp/atd/${tidalTrackVolume}${tidalTrackNumber} - $tidalTrackTitleSanitized.flac"
			flac -t "$file" && filecheck="pass" || filecheck="failed"
			if [ "$filecheck" = "pass" ]; then
				echo "PASSED"
			else
				echo "FAILED"
				sleep 100
			fi
			
			metaflac "$file" --remove-all-tags 	
			metaflac "$file" --set-tag=TITLE="$tidalTrackTitle"
			metaflac "$file" --set-tag=ALBUM="$tidalAlbumTitle"
			metaflac "$file" --set-tag=TRACKNUMBER="$tidalTrackNumber"
			metaflac "$file" --set-tag=DISCNUMBER="$tidalTrackVolume"
			metaflac "$file" --set-tag=TOTALTRACKS="$tidalAlbumNumberOfTracks"
			metaflac "$file" --set-tag=TOTALDISCS="$tidalAlbumNumberOfVolumes"
			metaflac "$file" --set-tag=ARTIST="$lidarrArtistName"
			metaflac "$file" --set-tag=ALBUMARTIST="$lidarrArtistName"
			#metaflac "$file" --set-tag=ALBUMARTISTS="$lidarrArtistName"
			#metaflac "$file" --set-tag=ARTISTS="$lidarrArtistName"
			#for id in ${!tidalTrackArtistsIds[@]}; do
			#	tidalTrackArtistId="${tidalTrackArtistsIds[$id]}"
			#	tidalTrackArtistData=$(echo "$tidalTrackData" | jq -r ".artists[] | select(.id==$tidalTrackArtistId)")
			#	if [ $tidalTrackArtistId = $tidalArtistId ]; then
			#		continue
			#	fi
			#	tidalTrackArtistName=$(echo "$tidalTrackArtistData" | jq -r ".name")
			#	tidalTrackArtistType=$(echo "$tidalTrackArtistData" | jq -r ".type")
			#	metaflac "$file" --set-tag=ARTISTS="$tidalTrackArtistName"
			#done
			
			metaflac "$file" --set-tag=MUSICBRAINZ_ALBUMARTISTID="$musicbrainzId"
			#metaflac "$file" --set-tag=LABEL="$tidalAlbumCopyright"
			metaflac "$file" --set-tag=YEAR="$tidalAlbumReleaseYear"
			metaflac "$file" --set-tag=DATE="$tidalAlbumReleaseDate"
			metaflac "$file" --set-tag=ISRC="$tidalTrackIsrc"
			metaflac "$file" --set-tag=EXPLICIT="$tidalTrackExplicit"
			metaflac "$file" --set-tag=BARCODE="$tidalAlbumUpc"
			#metaflac "$file" --set-tag=Media="Digital Media"
			#metaflac "$file" --set-tag=RELEASETYPE="${tidalAlbumType,,}"
			#if [ "$compilation" = "true" ]; then
			#	metaflac "$file" --set-tag=COMPILATION="1"
			#else
			#	if [ "$lidarrArtistName" = "Various Artists" ]; then
			#		metaflac "$file" --set-tag=COMPILATION="1"
			#	else
			#		metaflac "$file" --set-tag=COMPILATION="0"
			#	fi
			#fi

			if [ -f "/tmp/atd/${tidalTrackVolume}${tidalTrackNumber} - $tidalTrackTitleSanitized.lrc" ]; then
				log "$position :: $idNumber of $idListCount :: $tidalId :: Embedding lyrics (lrc)"
				metaflac --set-tag-from-file="Lyrics=/tmp/atd/${tidalTrackVolume}${tidalTrackNumber} - $tidalTrackTitleSanitized.lrc" "$file"
			fi

			#tidalTrackContributerCount=""
			#tidalTrackContributerName=""
			#tidalTrackContributerRole=""
			#tidalTrackContributerCount=$(echo $tidalTrackCredits | jq -r '.items[].name' | wc -l)

			#END=$tidalTrackContributerCount
			#for ((i=1;i<=END;i++)); do
			#	ID=$(expr $i - 1)
			#	tidalTrackContributerName=$(echo $tidalTrackCredits | jq -r .items[$ID].name)
			#	tidalTrackContributerRole=$(echo $tidalTrackCredits | jq -r .items[$ID].role)
			#	metaflac "$file" --set-tag="$tidalTrackContributerRole"="$tidalTrackContributerName"
			#done

			if [ ! -d "/tmp/import/$tidalAlbumFoldername" ]; then
				mkdir -p "/tmp/import/$tidalAlbumFoldername"
			fi
			find /tmp/atd -type f -exec mv {} "/tmp/import/$tidalAlbumFoldername"/ \;
			
		done
		if [ ! -d "$lidarrArtistPath" ]; then 
			mkdir -p "$lidarrArtistPath"
			chmod 777 "$lidarrArtistPath"
			chown abc:abc "$lidarrArtistPath"
		fi
		for file in "/tmp/import/$tidalAlbumFoldername"/*.flac; do
			if [ ! -z "$deezerAlbumGenre" ]; then
				log "$position :: $idNumber of $idListCount :: $tidalId :: Tagging Tracks with Deezer Genre"
				metaflac "$file" --set-tag=GENRE="${deezerAlbumGenre,,}"
			else
				log "$position :: $idNumber of $idListCount :: $tidalId :: Tagging Tracks with Artist Genres"
				for genre in ${!lidarrArtistGenres[@]}; do
					artistgenre="${lidarrArtistGenres[$genre]}"
					metaflac "$file" --set-tag=GENRE="${artistgenre,,}"
				done
			fi
		done
		ProcessWithBeets "/tmp/import/$tidalAlbumFoldername"
		functionName=ProcessTidalIdList
		if [ -d "/tmp/import/$tidalAlbumFoldername" ]; then
			if [ ! -d "$DownloadLocation/for_import" ]; then
				mkdir -p "$DownloadLocation/for_import"
				chmod 777 "$DownloadLocation/for_import"
				chown abc:abc "$DownloadLocation/for_import"
			fi
			AddReplaygainTags "/tmp/import/$tidalAlbumFoldername"
			functionName=ProcessTidalIdList
			if [ -d "$DownloadLocation/for_import/$tidalAlbumFoldername" ]; then
				rm -rf "$DownloadLocation/for_import/$tidalAlbumFoldername"
			fi
			mv "/tmp/import/$tidalAlbumFoldername" "$DownloadLocation/for_import/$tidalAlbumFoldername"
			chmod 777 "$DownloadLocation/for_import/$tidalAlbumFoldername"
			chown abc:abc "$DownloadLocation/for_import/$tidalAlbumFoldername"
			chmod 666 "$DownloadLocation/for_import/$tidalAlbumFoldername"/*
			chown abc:abc "$DownloadLocation/for_import/$tidalAlbumFoldername"/*

			NotifyLidarrForImport "$DownloadLocation/for_import/$tidalAlbumFoldername"
			functionName=ProcessTidalIdList
		fi
		log "$position :: $idNumber of $idListCount :: $tidalId :: End"
		#ffprobe -hide_banner -loglevel fatal -show_error -show_format -show_streams -show_programs -show_chapters -show_private_data -print_format json "$file" | jq -r ".format.tags.LYRICS" > $file.lrc

	done
	log "$position :: End"
}

DownloadTidalId () {
	functionName=DownloadTidalId
	log "$position :: Start"
	if [ ! -d "/tmp/atd" ]; then
		mkdir -p "/tmp/atd"
		chmod 777 "/tmp/atd"
		log "$position :: Creating temp folder"
	else
		rm -rf "/tmp/atd"
		mkdir -p "/tmp/atd"
		chmod 777 "/tmp/atd"
		log "$position :: Clearing temp folder data"
	fi
	if [ -d "/tmp" ]; then
	   	tidal-dl -o /tmp -l "$1"
	fi
	log "$position :: End"
}

ProcessWithBeets () {
	functionName=ProcessWithBeets
	log "$position :: Start"

	
	trackcount=$(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
	log "$position :: $idNumber of $idListCount :: $tidalId :: Matching $trackcount tracks with Beets"
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
		beet -c $SCRIPT_DIR/scripts/resources/beets-config.yaml -l /scripts/library.blb -d "$1" import -q "$1"
		if [ $(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -newer "/scripts/beets-match" | wc -l) -gt 0 ]; then
			log "$position :: $idNumber of $idListCount :: $tidalId :: SUCCESS: Matched with beets!"
		else
			rm -rf "$1" 
			echo "ERROR: Unable to match using beets to a musicbrainz release, marking download as failed..."
			touch "/scripts/beets-match-error"
		fi	
	fi

	if [ -f "/scripts/beets-match" ]; then 
		rm "/scripts/beets-match"
		sleep 0.1
	fi

	if [ -f "/scripts/beets-match-error" ]; then
		if [ ! -d "/config/logs/beets/unmatched" ]; then
			mkdir -p "/config/logs/beets/unmatched"
		fi
		log "$position :: $idNumber of $idListCount :: $tidalId :: ERROR :: Beets could not match album, skipping..."
		touch "/config/logs/beets/unmatched/$tidalId"
		rm "/scripts/beets-match-error"
		return
	else
		log "$position :: $idNumber of $idListCount :: $tidalId :: BEETS MATCH FOUND!"
	fi

	GetFile=$(find "$1" -type f -iname "*.flac" | head -n1)
	matchedTags=$(ffprobe -hide_banner -loglevel fatal -show_error -show_format -show_streams -show_programs -show_chapters -show_private_data -print_format json "$GetFile" | jq -r ".format.tags")
	matchedTagsAlbumReleaseGroupId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_RELEASEGROUPID")"
	matchedTagsAlbumTitle="$(echo $matchedTags | jq -r ".ALBUM")"
	matchedTagsAlbumArtist="$(echo $matchedTags | jq -r ".album_artist")"
	matchedTagsAlbumYear="$(echo $matchedTags | jq -r ".YEAR")"
	matchedTagsAlbumType="$(echo $matchedTags | jq -r ".RELEASETYPE")"
	tidalAlbumTitleSanitized=$(echo $matchedTagsAlbumTitle | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
	tidalAlbumFoldername="$tidalAlbumArtistSanitized - $tidalAlbumTitleSanitized ($matchedTagsAlbumYear)-WEB-${matchedTagsAlbumType^^}-atd"
	
	log "$position :: $idNumber of $idListCount :: $tidalId :: $matchedTagsAlbumReleaseGroupId"

	if [ -f "/config/logs/beets/matched/$matchedTagsAlbumReleaseGroupId" ]; then
		log "$position :: $idNumber of $idListCount :: $tidalId ::  ERROR :: Already Imported"
		touch "/config/logs/beets/matched/$tidalId"
		rm -rf "$1"
		return
	else
		if [ ! -d /config/logs/beets/matched ]; then
			mkdir -p /config/logs/beets/matched
		fi
		touch "/config/logs/beets/matched/$matchedTagsAlbumReleaseGroupId"
	fi

	if [ "$1" != "/tmp/import/$tidalAlbumFoldername" ]; then
		mv "$1" "/tmp/import/$tidalAlbumFoldername"
	fi

	for file in "/tmp/import/$tidalAlbumFoldername"/*.flac; do
		matchedTags=$(ffprobe -hide_banner -loglevel fatal -show_error -show_format -show_streams -show_programs -show_chapters -show_private_data -print_format json "$file" | jq -r ".format.tags")
		matchedTagsTrackId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_TRACKID")"
		matchedTagsTrackWorkId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_WORKID")"
		matchedTagsTrackReleaseId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_RELEASETRACKID")"
		matchedTagsTrackArtistId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_ARTISTID")"
		matchedTagsTrackAlbumArtistId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_ALBUMARTISTID")"
		matchedTagsTrackAlbumId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_ALBUMID")"
		matchedTagsTrackArtist="$(echo $matchedTags | jq -r ".ARTIST")"
		matchedTagsTrackExplicit="$(echo $matchedTags | jq -r ".EXPLICIT")"
		matchedTagsTrackTitle="$(echo $matchedTags | jq -r ".TITLE")"
		matchedTagsTrackNumber="$(echo $matchedTags | jq -r ".track")"
		matchedTagsTrackDisc="$(echo $matchedTags | jq -r ".disc")"
		matchedTagsTrackLyrics="$(echo $matchedTags | jq -r ".LYRICS")"
		matchedTagsTrackGenre="$(echo $matchedTags | jq -r ".GENRE" | head -n 1)"
		metaflac "$file" --remove-all-tags
		metaflac "$file" --set-tag=MUSICBRAINZ_ALBUMARTISTID="$matchedTagsTrackAlbumArtistId"
		metaflac "$file" --set-tag=MUSICBRAINZ_ALBUMID="$matchedTagsTrackAlbumId"
		metaflac "$file" --set-tag=MUSICBRAINZ_RELEASEGROUPID="$matchedTagsAlbumReleaseGroupId"
		metaflac "$file" --set-tag=YEAR="$matchedTagsAlbumYear"
		metaflac "$file" --set-tag=ALBUM="$matchedTagsAlbumTitle"
		metaflac "$file" --set-tag=MUSICBRAINZ_TRACKID="$matchedTagsTrackId"
		metaflac "$file" --set-tag=MUSICBRAINZ_WORKID="$matchedTagsTrackWorkId"
		metaflac "$file" --set-tag=MUSICBRAINZ_RELEASETRACKID="$matchedTagsTrackReleaseId"
		metaflac "$file" --set-tag=MUSICBRAINZ_ARTISTID="$matchedTagsTrackArtistId"
		metaflac "$file" --set-tag=ARTIST="$matchedTagsTrackArtist"
		metaflac "$file" --set-tag=EXPLICIT="$matchedTagsTrackExplicit"
		metaflac "$file" --set-tag=TITLE="$matchedTagsTrackTitle"
		metaflac "$file" --set-tag=TRACK="$matchedTagsTrackNumber"
		metaflac "$file" --set-tag=DISC="$matchedTagsTrackDisc"
		if [ "$matchedTagsTrackLyrics" != "null" ]; then
			metaflac "$file" --set-tag=LYRICS="$matchedTagsTrackLyrics"
		fi
		metaflac "$file" --set-tag=GENRE="$matchedTagsTrackGenre"
	done

	#LidarrAlbumData=$(curl -s --header "X-Api-Key:"${LidarrApiKey} --request GET  "$LidarrUrl/api/v1/album/" | jq -r ".[]")
	#lidarrPercentOfTracks=$(echo "$LidarrAlbumData" | jq -r "select(.foreignAlbumId==\"$matchedTagsAlbumReleaseGroupId\") | .statistics.percentOfTracks")
		
	log "$position :: End"
}

NotifyLidarrForImport () {
	functionName=NotifyLidarrForImport
	LidarrProcessIt=$(curl -s "$LidarrUrl/api/v1/command" --header "X-Api-Key:"${LidarrApiKey} -H "Content-Type: application/json" --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"$1\"}")
	log "$position :: $idNumber of $idListCount :: $tidalId :: LIDARR IMPORT NOTIFICATION SENT! :: $1"
}

AddReplaygainTags () {
	functionName=AddReplaygainTags
	log "$position :: Start"
	if [ "$EnableReplayGain" == "true" ]; then
		log "$position :: $idNumber of $idListCount :: $tidalId :: Adding Replaygain Tags using r128gain to files"
		r128gain -r -a -s "$1"
	fi
	log "$position :: End"
}


GetTemplate () {
	functionName=GetTemplate
	log "$position :: Start"
	
	log "$position :: End"
}




Configuration
GetLidarrArtistList
ProcessLidarrArtistList

log "############################################ SCRIPT COMPLETE"
if [ "$AutoStart" == "true" ]; then
	log "############################################ SCRIPT SLEEPING FOR $ScriptInterval"
fi
exit 0
