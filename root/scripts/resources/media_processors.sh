AddReplaygainTags () {
	if [ "$EnableReplayGain" == "true" ]; then
		log "$logheader :: Adding Replaygain Tags using r128gain to files"
		r128gain -r -a -s /downloads-atd/temp-complete
	fi
}
