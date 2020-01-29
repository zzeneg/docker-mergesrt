# docker-mergesrt
Docker container for monitoring subtitle files and merging them into video

## Features
- search for existing `*.lang.srt` files
- monitor for new `*.lang.srt` files
- merge subtitles to `mkv` files
- replace existing subtitles with the same language
- remove merged `*.lang.srt` files

## Requirements
- a folder with media files should be mapped to `/data`
- SRT file should have a language in its name in [ISO 639-2](https://en.wikipedia.org/wiki/List_of_ISO_639-2_codes) format, e.g. `name.eng.srt`. If you're using [Bazarr](https://www.bazarr.media/) to automatically download subtitles, you can set a post-processing script to automatically convert ISO 639-1 to ISO 639-2:
  ```bash
  mv "{{subtitles}}" "{{directory}}/{{episode_name}}.{{subtitles_language_code3}}.srt" && echo
  ```
  (`&& echo` is required because bazarr can't handle scripts ending with quotes)

## Usage
- docker-compose example
  ```yaml
  mergesrt:
    container_name: mergesrt
    build: https://github.com/zzeneg/docker-mergesrt.git 
    restart: unless-stopped
    volumes:
      - /media:/data
  ```