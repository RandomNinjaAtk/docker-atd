MusicbrainzConfigurationValidation () {
	# check for MusicbrainzMirror setting, if not set, set to default
	if [ -z "$MusicbrainzMirror" ]; then
		MusicbrainzMirror=https://musicbrainz.org
	fi
	# Verify Musicbrainz DB Connectivity
	musicbrainzdbtest=$(curl -s -A "$agent" "${MusicbrainzMirror}/ws/2/artist/f59c5520-5f46-4d2c-b2c4-822eabf53419?fmt=json")
	musicbrainzdbtestname=$(echo "${musicbrainzdbtest}"| jq -r '.name')
	if [ "$musicbrainzdbtestname" != "Linkin Park" ]; then
		log "$TITLESHORT: ERROR: Cannot communicate with Musicbrainz"
		log "$TITLESHORT: ERROR: Expected Response \"Linkin Park\", received response \"$musicbrainzdbtestname\""
		log "$TITLESHORT: ERROR: URL might be Invalid: $MusicbrainzMirror"
		log "$TITLESHORT: ERROR: Remote Mirror may be throttling connection..."
		log "$TITLESHORT: ERROR: Link used for testing: ${MusicbrainzMirror}/ws/2/artist/f59c5520-5f46-4d2c-b2c4-822eabf53419?fmt=json"
		log "$TITLESHORT: ERROR: Please correct error, consider using official Musicbrainz URL: https://musicbrainz.org"
		error=1
	else
		log "$TITLESHORT: Musicbrainz Mirror Valid: $MusicbrainzMirror"
		if echo "$MusicbrainzMirror" | grep -i "musicbrainz.org" | read; then
			if [ "$MusicbrainzRateLimit" != 1 ]; then
				MusicbrainzRateLimit="1.5"
			fi
			log "$TITLESHORT: Musicbrainz Rate Limit: $MusicbrainzRateLimit (Queries Per Second)"
		else
			log "$TITLESHORT: Musicbrainz Rate Limit: $MusicbrainzRateLimit (Queries Per Second)"
			MusicbrainzRateLimit="0$(echo $(( 100 * 1 / $MusicbrainzRateLimit )) | sed 's/..$/.&/')"
		fi
	fi
}
