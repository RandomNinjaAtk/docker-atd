#!/usr/bin/with-contenv bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
agent="automated-tidal-downloader ( https://github.com/RandomNinjaAtk/docker-atd )"
DownloadLocation="/downloads-atd"
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

Configuration () {
	processstartid="$(ps -A -o pid,cmd|grep "start.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	processdownloadid="$(ps -A -o pid,cmd|grep "download.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	log "To kill script, use the following command:"
	log "kill -9 $processstartid"
	log "kill -9 $processdownloadid"
	log ""
	log ""
	sleep 2
	log "############# $TITLE - Video"
	log "############# SCRIPT VERSION 1.0.19"
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
    echo $m_time" "$1
}

LidarrConnection () {

	lidarrdata=$(curl -s --header "X-Api-Key:"${LidarrApiKey} --request GET  "$LidarrUrl/api/v1/Artist/")
	artisttotal=$(echo "${lidarrdata}"| jq -r '.[].sortName' | wc -l)
	lidarrlist=($(echo "${lidarrdata}" | jq -r ".[].foreignArtistId"))
	log "############# Video Downloads"

	for id in ${!lidarrlist[@]}; do
		artistnumber=$(( $id + 1 ))
		mbid="${lidarrlist[$id]}"
		artistdata=$(echo "${lidarrdata}" | jq -r ".[] | select(.foreignArtistId==\"${mbid}\")")
		artistname="$(echo "${artistdata}" | jq -r " .artistName")"
        artistnamepath="$(echo "${artistdata}" | jq -r " .path")"
		artistfolder="$(basename "${artistnamepath}")"
		sanitizedartistname="$(basename "${artistnamepath}" | sed 's% (.*)$%%g')"
		if [ -d "$DownloadLocation/video/$artistfolder" ]; then
			totaldownloadcount=$(find "$DownloadLocation/video/$artistfolder" -mindepth 1 -maxdepth 3 -type f -iname "*.mkv" | wc -l)
		else
			totaldownloadcount=0
		fi

        if [ -f "/config/logs/$sanitizedartistname-$mbid-complete" ]; then
            if ! [[ $(find "/config/logs/$sanitizedartistname-$mbid-complete" -mtime +7 -print) ]]; then
                log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: Already downloaded all ($totaldownloadcount) videos, skipping until expires..."
                continue
            fi
        fi
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
        log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: Processing.."
        videoidlist=""
		artist_id=$tidalartistid				
		videos_data=$(curl -s "https://api.tidal.com/v1/artists/${artist_id}/videos?countryCode=${CountryCode}&offset=0&limit=50" -H "x-tidal-token: CzET4vdadNUFQ5JU")
		items_total=$(echo "$videos_data" | jq -r ".totalNumberOfItems")
		if [ $items_total -le 50 ]; then
			video_ids=$(echo "$videos_data" | jq -r ".items[].id")
		else
			if [ ! -f "/config/cache/$sanitizedartistname-$mbid-tidal-videos.json" ]; then
				video_ids=$(cat "/config/cache/$sanitizedartistname-$mbid-tidal-videos.json" | jq -r ".[].items[].id")
				videoidscount=$(echo "$video_ids" | wc -l)
				if [ $items_total != $videoidscount ]; then
					rm -rf /config/cache/$sanitizedartistname-$mbid-tidal-videos.json
				fi
			fi
			
			if [ ! -f "/config/cache/$sanitizedartistname-$mbid-tidal-videos.json" ]; then
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
						curl -s "https://api.tidal.com/v1/artists/${artist_id}/videos?countryCode=${CountryCode}&offset=$offset&limit=50" -H "x-tidal-token: CzET4vdadNUFQ5JU" -o "/config/temp/$mbid-releases-page-$i.json"
						sleep 0.1
					fi
				done


				if [ ! -f "/config/cache/$sanitizedartistname-$mbid-tidal-videos.json" ]; then
					jq -s '.' /config/temp/$mbid-releases-page-*.json > "/config/cache/$sanitizedartistname-$mbid-tidal-videos.json"
				fi

				if [ -f "/config/cache/$sanitizedartistname-$mbid-tidal-videos.json" ]; then
					rm /config/temp/$mbid-releases-page-*.json
					sleep .01
				fi

				if [ -d "/config/temp" ]; then
					sleep 0.1
					rm -rf "/config/temp"
				fi
			fi
			video_ids=$(cat "/config/cache/$sanitizedartistname-$mbid-tidal-videos.json" | jq -r ".[].items[].id" | sort -u)
		fi

        videoids=($(echo "$video_ids"))
        videoidscount=$(echo "$video_ids" | wc -l)
		
		
        if [ $totaldownloadcount == $videoidscount ]; then
            log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $totaldownloadcount VIDEOS DOWNLOADED"
            touch "/config/logs/$sanitizedartistname-$mbid-complete"
            continue
        fi
        for id in ${!videoids[@]}; do
            currentprocess=$(( $id + 1 ))
            videoid="${videoids[$id]}"
			if [ -d "$DownloadLocation/video/$artistfolder" ]; then
				if find "$DownloadLocation/video/$artistfolder" -type f -iname "tidal_video_id_${videoid}_" | read; then
					log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: VideoID ($videoid) :: Already Downloaded, skipping..."
					continue
				fi
			fi
			video_data=$(curl -s "https://api.tidal.com/v1/videos/$videoid?countryCode=${CountryCode}" -H 'x-tidal-token: CzET4vdadNUFQ5JU' | jq -r)
			title=$(echo "$video_data" | jq -r ".title")
			clean_title="$(echo "$title" | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
			version=$(echo "$video_data" | jq -r ".version")
			volume_number=$(echo "$video_data" | jq -r ".volumeNumber")
			track_number=$(echo "$video_data" | jq -r ".trackNumber")
			explicit=$(echo "$video_data" | jq -r ".explicit")
			release_date=$(echo "$video_data" | jq -r ".releaseDate")
			release_year=${release_date:0:4}
			image_id=$(echo "$video_data" | jq -r ".imageId")
			image_id_fix=$(echo "$image_id" | sed "s/-/\//g")
			album_title=$(echo "$video_data" | jq -r ".album.title")
			artists_id=$(echo "$video_data" | jq -r ".artist.id")
			artists_ids=($(echo "$video_data" | jq -r ".artists[].id"))
			thumb="https://resources.tidal.com/images/$image_id_fix/750x500.jpg"
			if [ $tidalartistid != $artists_id ]; then
				log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: VideoID ($videoid) :: Artist ID does not match wanted artist, skipping..."
				
				count="0"
					query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://listen.tidal.com/artist/${artists_id}%22&fmt=json")
						count=$(echo "$query_data" | jq -r ".count")
						if [ "$count" == "0" ]; then
							sleep 1.5
							query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://tidal.com/artist/${artists_id}%22&fmt=json")
							count=$(echo "$query_data" | jq -r ".count")
							sleep 1.5
						fi
						
						if [ "$count" == "0" ]; then
							query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22http://tidal.com/browse/artist/${artists_id}%22&fmt=json")
							count=$(echo "$query_data" | jq -r ".count")
							sleep 1.5
						fi
						
						if [ "$count" == "0" ]; then
							query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://tidal.com/browse/artist/${artists_id}%22&fmt=json")
							count=$(echo "$query_data" | jq -r ".count")
						fi
						
						if [ "$count" != "0" ]; then
							musicbrainz_main_artist_id=$(echo "$query_data" | jq -r '.urls[]."relation-list"[].relations[].artist.id' | head -n 1)
							sleep 1.5
							artist_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/artist/$musicbrainz_main_artist_id?fmt=json")
							artist_sort_name="$(echo "$artist_data" | jq -r '."sort-name"')"
							artist_formed="$(echo "$artist_data" | jq -r '."begin-area".name')"
							artist_born="$(echo "$artist_data" | jq -r '."life-span".begin')"
							gender="$(echo "$artist_data" | jq -r ".gender")"
							matched_id=true
							data=$(curl -s "$LidarrUrl/api/v1/search?term=lidarr%3A$musicbrainz_main_artist_id" -H "X-Api-Key: $LidarrApiKey" | jq -r ".[]")
							artistName="$(echo "$data" | jq -r ".artist.artistName")"
							foreignId="$(echo "$data" | jq -r ".foreignId")"
							data=$(curl -s "$LidarrUrl/api/v1/rootFolder" -H "X-Api-Key: $LidarrApiKey" | jq -r ".[]")
							path="$(echo "$data" | jq -r ".path")"
							qualityProfileId="$(echo "$data" | jq -r ".defaultQualityProfileId")"
							metadataProfileId="$(echo "$data" | jq -r ".defaultMetadataProfileId")"
							data="{
								\"artistName\": \"$artistName\",
								\"foreignArtistId\": \"$foreignId\",
								\"qualityProfileId\": $qualityProfileId,
								\"metadataProfileId\": $metadataProfileId,
								\"rootFolderPath\": \"$path\"
								}"
							log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: VideoID ($videoid) :: Adding Artist to Lidarr ($musicbrainz_main_artist_id)..."
							curl -s "$LidarrUrl/api/v1/artist" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $LidarrApiKey" --data-raw "$data"
						else
							matched_id=false
						fi
				
				
				continue
			fi

			if [ "$explicit" = "false" ]; then
				songlyricrating="0"
			else
				songlyricrating="1"
			fi
			if [ "$image_id" == "null" ]; then
				thumb="null"
			fi
			if [ "$album_title" == "null" ]; then
				album_title="Music Videos"
			fi
			if [ "$version" == "null" ]; then
				version=""
			else
				version=" ($version)"
			fi
			clean_version="$(echo "$version" | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
			artists_names=()
			for id in ${!artists_ids[@]}; do
				subprocess=$(( $id + 1 ))
				artist_id=${artists_ids[$id]}
				artist_name=$(echo "$video_data" | jq -r ".artists[] | select(.id==$artist_id) | .name")
				artists_names+=("$artist_name")
				OUT=$OUT"$artist_name / "

			done
			artist_names="${OUT%???}"
			OUT=""
			main_artist=""
			main_artist_id="unset"
			clean_main_artists_name=""
			main_artists_names=()
			for id in ${!artists_ids[@]}; do
				subprocess=$(( $id + 1 ))
				artist_id=${artists_ids[$id]}
				artist_name=$(echo "$video_data" | jq -r ".artists[] | select(.id==$artist_id) | .name")
				artist_type=$(echo "$video_data" | jq -r ".artists[] | select(.id==$artist_id) | .type")
				if [ "$artist_type" == "MAIN" ]; then
					main_artists_names+=("$artist_name")
					OUT=$OUT"$artist_name / "
				fi
				if [ "$main_artist_id" == "unset" ]; then
					if [ "$artist_type" == "MAIN" ]; then
						main_artist="$artist_name"
						main_artist_id="$artist_id"
						clean_main_artists_name="$(echo "$main_artist" | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
					fi
				fi
			done
			main_artists_names="${OUT%???}"
			OUT=""
			
			USEFOLDERS=true
			if [ "$USEFOLDERS" == "true" ]; then
				destination="$DownloadLocation/video/$artistfolder/$clean_title${clean_version}${extendedFileName}"
			else
				destination="$DownloadLocation/video/$artistfolder"
			fi
			destinationFileName="$clean_title${clean_version}${extendedFileName}"
			extendedFileName=""
			if [ -f "/$destination/$destinationFileName.mkv" ]; then
				foundFileCount=$(find "$DownloadLocation/video/$artistfolder" -type f -iname "$destinationFileName*.mkv" | grep "(Alternate Version" | wc -l)
				if [ $foundFileCount = 0 ]; then
				 	extendedFileName=" (Alternate Version)"
				else
					foundFileCount=$(( $foundFileCount + 1 ))
					extendedFileName=" (Alternate Version $foundFileCount)"
				fi
			fi
			destinationFileName="$clean_title${clean_version}${extendedFileName}"

			if [ "$USEFOLDERS" == "true" ]; then
				destination="$DownloadLocation/video/$artistfolder/$clean_title${clean_version}${extendedFileName}"
			else
				destination="$DownloadLocation/video/$artistfolder"
			fi
			
			if [ -d "$DownloadLocation/video/$artistfolder" ]; then
				if [ -f "/$destination/$destinationFileName.mkv" ]; then
					log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: VideoID ($videoid) :: Already Downloaded, skipping..."
					continue
				elif find "$DownloadLocation/video/$artistfolder" -type f -iname "tidal_video_id_${videoid}_" | read; then
					log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: VideoID ($videoid) :: Already Downloaded, skipping..."
					continue
				fi
			fi
			log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: VideoID ($videoid) :: Sending to Download Client..."
            touch temp
            if [ -d "/tmp/atd" ]; then
                rm -rf "/tmp/atd"
            fi
			
			# Video Contributers
			VideoContributers=""
			VideoDirectors=""
			VideoDirector=""
			VideoPublishers=""
			VideoPublisher=""
			VideoContributerCount=""
			VideoContributerName=""
			VideoContributerRole=""
			VideoContributers=$(curl -s "https://listen.tidal.com/v1/videos/$videoid/contributors?limit=100&countryCode=${CountryCode}" -H "x-tidal-token: CzET4vdadNUFQ5JU")
			VideoContributerCount=$(echo $VideoContributers | jq -r '.items[].name' | wc -l)
						
			OLDIFS="$IFS"
			IFS=$'\n'
			VideoDirectors=($(echo $VideoContributers | jq -r '.items[] | select(.role=="Video Director") | .name'))
			VideoPublishers=($(echo $VideoContributers | jq -r '.items[] | select(.role=="Music Publisher") | .name'))
			IFS="$OLDIFS"

			if [ ! -d "/tmp/atd" ]; then
				mkdir -p "/tmp/atd"
				chmod 777 "/tmp/atd"
				log "Creating temp folder"
			else
				rm -rf "/tmp/atd"
				mkdir -p "/tmp/atd"
				chmod 777 "/tmp/atd"
				log "Clearing temp folder data"
			fi
			
			if [ -d "/tmp" ]; then
		    	tidal-dl -o /tmp/atd -l "https://tidal.com/browse/video/$videoid"
			fi
            find "/tmp/atd" -type f -iname "*.mp4" -newer "temp" -print0 | while IFS= read -r -d '' video; do
                count=$(($count+1))
                file="${video}"
				filenoext="${file%.*}"
                filename="$(basename "$video")"
                extension="${filename##*.}"
                filenamenoext="${filename%.*}"

				if [ "$thumb" != "null" ]; then
					curl -s "$thumb" -o "/tmp/atd/thumb.jpg"
				else
					ffmpeg -y \
						-i "$file" \
						-vframes 1 -an -s 640x360 -ss 30 \
						"/tmp/atd/thumb.jpg" &> /dev/null
				fi

				if python3 /usr/local/sma/manual.py --config "/local_configs/sma.ini" -i "$file" -nt &>/dev/null; then
					sleep 0.01
					log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: VideoID ($videoid) :: Processed with SMA..."
					rm  /usr/local/sma/config/*log*
				else
					log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: VideoID ($videoid) :: ERROR: SMA Processing Error"
					rm "$video" && log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: VideoID ($videoid) :: INFO: deleted: $filename"
				fi
			
				OLDIFS="$IFS"
				IFS=$'\n'
				artistgenres=($(echo "$mbzartistinfo" | jq -r ".genres[].name"))
				IFS="$OLDIFS"
				for genre in ${!artistgenres[@]}; do
					artistgenre="${artistgenres[$genre]}"
					OUT=$OUT"$artistgenre / "
				done
				genre="${OUT%???}"
				genre="$(echo "$genre" | sed -E 's/(\w)(\w*)/\U\1\L\2/g')"

				mv "$filenoext.mkv" "/tmp/atd/temp.mkv"
				cp "/tmp/atd/thumb.jpg" "/tmp/atd/cover.jpg"
				log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: VideoID ($videoid) :: Tagging file"
				ffmpeg -y \
					-i "/tmp/atd/temp.mkv" \
					-c copy \
					-metadata TITLE="$title${version}${extendedFileName}" \
					-metadata DATE_RELEASE="$release_date" \
					-metadata DATE="$release_date" \
					-metadata YEAR="$release_year" \
					-metadata GENRE="$genre" \
					-metadata TRACK_NUMBER="$track_number" \
					-metadata ALBUM="$album_title" \
					-metadata ARTIST="$artist_names" \
					-metadata ALBUMARTIST="$main_artists_names" \
					-metadata ENCODED_BY="ATD" \
					-attach "/tmp/atd/cover.jpg" -metadata:s:t mimetype=image/jpeg \
					"$filenoext.mkv" &>/dev/null
				log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: VideoID ($videoid) :: Tagging complete!"
								
				if [ ! -d "$destination" ]; then
					mkdir -p "$destination"
					chmod 777 "$destination"
					chown abc:abc "$destination"
				fi

                mv "$filenoext.mkv" "/$destination/$destinationFileName.mkv"
				cp "/tmp/atd/cover.jpg" "/$destination/$destinationFileName.jpg"
				chmod 666 "/$destination/$destinationFileName.mkv"
				chmod 666 "/$destination/$destinationFileName.jpg"
				chown abc:abc "/$destination/$destinationFileName.mkv"
				chown abc:abc "/$destination/$destinationFileName.jpg"

				log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: DOWNLOADED :: $destinationFileName.$extension"
				
				if [ "$USEFOLDERS" == "true" ]; then
					if [ "$USEFOLDERS" == "true" ]; then
						nfo="/$destination/../artist.nfo"
					else
						nfo="/$destination/artist.nfo"
					fi
					if [ ! -f "$nfo" ]; then
						#artist
						curl -s "https://listen.tidal.com/v1/pages/artist?artistId=${main_artist_id}&locale=en_US&deviceType=BROWSER&countryCode=US" -H 'x-tidal-token: CzET4vdadNUFQ5JU' -o "/config/cache/$clean_main_artists_name-${main_artist_id}-tidal-artist.json"
						artist_data=$(cat "/config/cache/$clean_main_artists_name-${main_artist_id}-tidal-artist.json")
						artist_biography="$(echo "$artist_data" | jq -r ".rows[].modules[] | select(.type==\"ARTIST_HEADER\") | .bio.text" | sed -e 's/\[[^][]*\]//g' | sed -e 's/<br\/>//g')"
						artist_picture_id="$(echo "$artist_data" | jq -r ".rows[].modules[] | select(.type==\"ARTIST_HEADER\") | .artist.picture")"
						artist_picture_id_fix=$(echo "$artist_picture_id" | sed "s/-/\//g")
						thumb="https://resources.tidal.com/images/$artist_picture_id_fix/750x750.jpg"
						count="0"
						query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://listen.tidal.com/artist/${main_artist_id}%22&fmt=json")
						count=$(echo "$query_data" | jq -r ".count")
						if [ "$count" == "0" ]; then
							sleep 1.5
							query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://tidal.com/artist/${main_artist_id}%22&fmt=json")
							count=$(echo "$query_data" | jq -r ".count")
							sleep 1.5
						fi
						
						if [ "$count" == "0" ]; then
							query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22http://tidal.com/browse/artist/${main_artist_id}%22&fmt=json")
							count=$(echo "$query_data" | jq -r ".count")
							sleep 1.5
						fi
						
						if [ "$count" == "0" ]; then
							query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://tidal.com/browse/artist/${main_artist_id}%22&fmt=json")
							count=$(echo "$query_data" | jq -r ".count")
						fi
						
						if [ "$count" != "0" ]; then
							musicbrainz_main_artist_id=$(echo "$query_data" | jq -r '.urls[]."relation-list"[].relations[].artist.id' | head -n 1)
							sleep 1.5
							artist_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/artist/$musicbrainz_main_artist_id?fmt=json")
							artist_sort_name="$(echo "$artist_data" | jq -r '."sort-name"')"
							artist_formed="$(echo "$artist_data" | jq -r '."begin-area".name')"
							artist_born="$(echo "$artist_data" | jq -r '."life-span".begin')"
							gender="$(echo "$artist_data" | jq -r ".gender")"
							matched_id=true
						else
							matched_id=false
						fi
										
						echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>" >> "$nfo"
						echo "<artist>" >> "$nfo"
						echo "	<name>${main_artist}</name>" >> "$nfo"
						if [ "$matched_id" == "true" ]; then
							echo "	<musicBrainzArtistID>$musicbrainz_main_artist_id</musicBrainzArtistID>" >> "$nfo"
							echo "	<sortname>$artist_sort_name</sortname> " >> "$nfo"
							echo "	<gender>$gender</gender>" >> "$nfo"
							echo "	<born>$artist_born</born>" >> "$nfo"
						else
							echo "	<musicBrainzArtistID/>" >> "$nfo"
						fi
						if [ "$artist_picture_id" == "null" ]; then
							echo "	<thumb/>" >> "$nfo"
						else
							if [ "$USEFOLDERS" == "true" ]; then
								curl -s "$thumb" -o "/$destination/../poster.jpg"
								chmod 666 "/$destination/../poster.jpg"
								chown abc:abc "/$destination/../poster.jpg"
							else
								curl -s "$thumb" -o "/$destination/poster.jpg"
								chmod 666 "/$destination/poster.jpg"
								chown abc:abc "/$destination/poster.jpg"
							fi
							echo "	<thumb aspect=\"poster\" preview=\"poster.jpg\">poster.jpg</thumb>" >> "$nfo"
						fi
						echo "</artist>" >> "$nfo"
						chmod 666 "$nfo"
						chown abc:abc "$nfo"
						tidy -w 2000 -i -m -xml "$nfo" &>/dev/null
					fi
				fi
				
				nfo="/$destination/$destinationFileName.nfo"
				if [ -f "/$destination/$destinationFileName.mkv" ]; then
					log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: NFO WRITER :: Writing NFO for $clean_title${clean_version} ($videoid)"
					if [ ! -f "$nfo" ]; then
						echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>" >> "$nfo"
						echo "<musicvideo>" >> "$nfo"
						echo "	<title>${title}${version}${extendedFileName}</title>" >> "$nfo"
						echo "	<userrating/>" >> "$nfo"
						if [ $track_number == 0 ]; then
							echo "	<track/>" >> "$nfo"
						else
							echo "	<track>$track_number</track>" >> "$nfo"
						fi
						echo "	<album>Music Videos</album>" >> "$nfo"
						echo "	<plot/>" >> "$nfo"
						if [ ! -z "$VideoDirectors" ]; then
							for name in ${!VideoDirectors[@]}; do
								VideoDirector="${VideoDirectors[$name]}"
								echo "	<director>$VideoDirector</director>" >> "$nfo"
							done
						else
							echo "	<director/>" >> "$nfo"
						fi
						echo "	<premiered>$release_date</premiered>" >> "$nfo"
						echo "	<year>$release_year</year>" >> "$nfo"
						if [ ! -z "$VideoPublishers" ]; then
							for name in ${!VideoPublishers[@]}; do
								VideoPublisher="${VideoPublishers[$name]}"
								echo "	<studio>$VideoPublisher</studio>" >> "$nfo"
							done
						else
							echo "	<studio/>" >> "$nfo"
						fi
						OLDIFS="$IFS"
						IFS=$'\n'
						artistgenres=($(echo "$mbzartistinfo" | jq -r ".genres[].name"))
						IFS="$OLDIFS"
						for genre in ${!artistgenres[@]}; do
							artistgenre="${artistgenres[$genre]}"
							artistgenre="$(echo "$artistgenre" | sed -E 's/(\w)(\w*)/\U\1\L\2/g')"
							echo "	<genre>$artistgenre</genre>" >> "$nfo"
						done
						for name in ${!artists_names[@]}; do
							artist_name="${artists_names[$name]}"
							echo "	<artist>$artist_name</artist>" >> "$nfo"
						done 
						
						#END=$VideoContributerCount
						#for ((i=1;i<=END;i++)); do
						#	ID=$(expr $i - 1)
						#	VideoContributerName=$(echo $VideoContributers | jq -r .items[$ID].name)
						#	VideoContributerRole=$(echo $VideoContributers | jq -r .items[$ID].role)
						#	if [ "$VideoContributerRole" == "Video Director" ] || [ "$VideoContributerRole" == "Music Publisher" ]; then 
						#		continue
						#	fi
						#	echo "	<actor>" >> "$nfo"
						#	echo "		<name>$VideoContributerName</name>" >> "$nfo"
						#	echo "		<role>$VideoContributerRole</role>" >> "$nfo"
						#	echo "		<order>$ID</order>" >> "$nfo"
						#	echo "		<thumb/>" >> "$nfo"
						#	echo "	</actor>" >> "$nfo"
						#done

						if [ -f "/$destination/$destinationFileName.jpg" ]; then
							echo "	<thumb>$destinationFileName.jpg</thumb>" >> "$nfo"
						else
							echo "	<thumb/>" >> "$nfo"
						fi
						echo "</musicvideo>" >> "$nfo"
						chmod 666 "/$destination/$destinationFileName.jpg"
						chown abc:abc "/$destination/$destinationFileName.jpg"
						chmod 666 "$nfo"
						chown abc:abc "$nfo"
						tidy -w 2000 -i -m -xml "$nfo" &>/dev/null
						log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: NFO WRITER :: COMPLETE"
						touch "/$destination/tidal_video_id_${videoid}_"
						log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $currentprocess of $videoidscount :: MARK COMPLETE"
					fi
				fi
			
			done
            rm temp
            if [ -d "/tmp/atd" ]; then
                rm -rf "/tmp/atd"
            fi
        done
        touch "/config/logs/$sanitizedartistname-$mbid-complete"
        totaldownloadcount=$(find "$DownloadLocation/video/$artistfolder" -mindepth 1 -maxdepth 3 -type f -iname "*.mkv" | wc -l)
        log "$artistnumber of $artisttotal :: $artistname :: TIDAL :: $totaldownloadcount VIDEOS DOWNLOADED"
	done
	totaldownloadcount=$(find "$DownloadLocation/video" -mindepth 1 -maxdepth 3 -type f -iname "*.mkv" | wc -l)
	log "############# $totaldownloadcount VIDEOS DOWNLOADED"
}


Configuration
LidarrConnection

log "############################################ SCRIPT COMPLETE"
if [ "$AutoStart" == "true" ]; then
	log "############################################ SCRIPT SLEEPING FOR $ScriptInterval"
fi
exit 0
