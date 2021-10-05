# ATD - Automated Tidal Downloader
[![Docker Build](https://img.shields.io/docker/cloud/automated/randomninjaatk/atd?style=flat-square)](https://hub.docker.com/r/randomninjaatk/atd)
[![Docker Pulls](https://img.shields.io/docker/pulls/randomninjaatk/atd?style=flat-square)](https://hub.docker.com/r/randomninjaatk/atd)
[![Docker Stars](https://img.shields.io/docker/stars/randomninjaatk/atd?style=flat-square)](https://hub.docker.com/r/randomninjaatk/atd)
[![Docker Hub](https://img.shields.io/badge/Open%20On-DockerHub-blue?style=flat-square)](https://hub.docker.com/r/randomninjaatk/atd)
[![Discord](https://img.shields.io/discord/747100476775858276.svg?style=flat-square&label=Discord&logo=discord)](https://discord.gg/JumQXDc "realtime support / chat with the community." )

[RandomNinjaAtk/atd](https://github.com/RandomNinjaAtk/docker-atd) is a script to automatically archive music for use in other audio applications (plex/kodi/jellyfin/emby) 

[![RandomNinjaAtk/atd](https://raw.githubusercontent.com/RandomNinjaAtk/unraid-templates/master/randomninjaatk/img/ama.png)](https://github.com/RandomNinjaAtk/docker-ama)

## Supported Architectures

The architectures supported by this image are:

| Architecture | Tag |
| :----: | --- |
| x86-64 | latest |

## Version Tags

| Tag | Description |
| :----: | --- |
| latest | Newest release code |


## Parameters

Container images are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container.

| Parameter | Function |
| --- | --- |
| `-e PUID=1000` | for UserID - see below for explanation |
| `-e PGID=1000` | for GroupID - see below for explanation |
| `-v /config` | Configuration files for ATD |
| `-v /downloads-atd` | Downloaded library location |
| `-e AutoStart=true` | true = Enabled :: Runs script automatically on startup |
| `-e ScriptInterval=15m` | #s or #m or #h or #d :: s = seconds, m = minutes, h = hours, d = days :: Amount of time between each script run, when AUTOSTART is enabled|
| `-e LidarrUrl=http://x.x.x.x:8686` | REQUIRED: Lidarr URL, Lidarr provides artist list for processing with ATD... |
| `-e LidarrApiKey=08d108d108d108d108d108d108d108d1` | REQUIRED: Lidarr API Key, enables ATD to connect to Lidarr... |
| `-e MusicbrainzMirror=https://musicbrainz.org` | OPTIONAL :: Only change if using a different mirror |
| `-e MusicbrainzRateLimit=1` | OPTIONAL: musicbrainz rate limit, musicbrainz allows only 1 connection per second, max setting is 10 :: Set to 101 to disable limit |
| `-e ScriptMode=both` | REQUIRED: set to: music or video or both :: both downloads music and videos, the others set the download to the desired media type |

## Instructions

Only videos work at this time.<br/>
To execute script from CLI, do the following:<br/>
`docker exec -it atd /bin/bash`<br/>
`bash /config/scripts/video.sh`

## Usage

Here are some example snippets to help you get started creating a container.

### docker

```
docker create \
  --name=atd \
  -v /path/to/config/files:/config \
  -v /path/to/downloads:/downloads-atd \
  -e PUID=1000 \
  -e PGID=1000 \
  -e AutoStart=true \
  -e ScriptInterval=1h \
  -e LidarrUrl=http://x.x.x.x:8686 \
  -e LidarrApiKey=LIDARRAPI \
  -e MusicbrainzMirror=https://musicbrainz.org \
  -e MusicbrainzRateLimit=1 \
  -e ScriptMode=both \
  --restart unless-stopped \
  randomninjaatk/atd 
```


### docker-compose

Compatible with docker-compose v2 schemas.

```
version: "2.1"
services:
  amd:
    image: randomninjaatk/atd 
    container_name: atd
    volumes:
      - /path/to/config/files:/config
      - /path/to/downloads:/downloads-atd
    environment:
      - PUID=1000
      - PGID=1000
      - AutoStart=true
      - ScriptInterval=1h
      - LidarrUrl=http://x.x.x.x:8686
      - LidarrApiKey=LIDARRAPI
      - MusicbrainzMirror=https://musicbrainz.org
      - MusicbrainzRateLimit=1
      - ScriptMode=both
    restart: unless-stopped
```
