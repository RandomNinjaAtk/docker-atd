FROM lsiobase/ubuntu:focal
LABEL maintainer="RandomNinjaAtk"

ENV TITLE="Automated Tidal Downloader (ATD)"
ENV TITLESHORT="ATD"
ENV VERSION="1.0.015"
ENV SMA_PATH /usr/local/sma
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
		tidy \
		git \
		wget \
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
		tidal-dl \
		qtfaststart && \
	pip3 install git+https://github.com/nathom/streamrip.git@dev && \
	echo "************ setup SMA ************" && \
	echo "************ setup directory ************" && \
	mkdir -p ${SMA_PATH} && \
	echo "************ download repo ************" && \
	git clone https://github.com/mdhiggins/sickbeard_mp4_automator.git ${SMA_PATH} && \
	mkdir -p ${SMA_PATH}/config && \
	echo "************ create logging file ************" && \
	mkdir -p ${SMA_PATH}/config && \
	touch ${SMA_PATH}/config/sma.log && \
	chgrp users ${SMA_PATH}/config/sma.log && \
	chmod g+w ${SMA_PATH}/config/sma.log && \
	echo "************ install pip dependencies ************" && \
	python3 -m pip install --user --upgrade pip && \	
	pip3 install -r ${SMA_PATH}/setup/requirements.txt && \
	echo "************ install beets ************" && \
	pip3 install https://github.com/beetbox/beets/tarball/master && \
	pip3 install pyacoustid
		
# copy local files
COPY root/ /
 
# set work directory
WORKDIR /config
