FROM lsiobase/ubuntu:focal
LABEL maintainer="RandomNinjaAtk"

ENV TITLE="Automated Tidal Downloader (ATD)"
ENV TITLESHORT="ATD"
ENV VERSION="1.0.001"
RUN \
	echo "************ install dependencies ************" && \
	echo "************ install and upgrade packages ************" && \
	apt-get update && \
	apt-get upgrade -y && \
	apt-get install -y --no-install-recommends \
		netbase \
		jq \
		flac \
		eyed3 \
		python3 \
		ffmpeg \
		opus-tools \
		python3-pip && \
	rm -rf \
		/tmp/* \
		/var/lib/apt/lists/* \
		/var/tmp/* && \
	echo "************ install python packages ************" && \
	python3 -m pip install --no-cache-dir -U \
		yq \
		mutagen \
		r128gain \
		tidal-dl
 

# copy local files
COPY root/ /

# set work directory
WORKDIR /config
