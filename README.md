# docker-mergesrt
Docker container for monitoring subtitle files and merging them into video

Published on [Docker Hub](https://hub.docker.com/r/zzeneg/mergesrt)

## Features
- search for existing `*.lang.srt` files
- monitor for new `*.lang.srt` files
- merge subtitles to `mkv` files
- replace existing subtitles with the same language
- remove merged `*.lang.srt` files
- send notification to a webhook after a merge (success/fail)

## Requirements
- a folder with media files should be mapped to `/data`
- SRT file should have a language in its name in [ISO 639-2](https://en.wikipedia.org/wiki/List_of_ISO_639-2_codes) format, e.g. `name.eng.srt`. If you're using [Bazarr](https://www.bazarr.media/) to automatically download subtitles, you can set a post-processing script to automatically convert ISO 639-1 to ISO 639-2:
  ```bash
  mv "{{subtitles}}" "{{directory}}/{{episode_name}}.{{subtitles_language_code3}}.srt" && echo
  ```
  (`&& echo` is required because bazarr can't handle scripts ending with quotes)


## Usage
- specify environment variables for a webhook (optional):
  - `WEBHOOK_URL` - URL for the POST request. For example you can use [Apprise](https://github.com/caronc/apprise)
  - `WEBHOOK_TEMPLATE` - template for the POST request body. Note that all double quotes `"` should be escaped by a backslash `\` and dollar signs `$` should be doubled. You can use variables in this template:
    - `$SRT_FILE` - full path to the subtitle file
    - `$MKV_FILE` - full path to the video file
    - `$LANG` - ISO 639-2 language code of the subtitles 
    - `$RESULT` - merge result, returns `merge succeeded` if subtitles were merged, `merge failed: {mkvmerge log}` otherwise

- docker-compose example
  ```yaml
  mergesrt:
    container_name: mergesrt
    image: zzeneg/mergesrt
    restart: unless-stopped
    environment:
      WEBHOOK_URL: http://apprise:8000/notify
      WEBHOOK_TEMPLATE: '{\"title\":\"*MergeSRT notification*\", \"body\":\""$$SRT_FILE: $$RESULT"\"}'
    volumes:
      - /media:/data

  apprise:
    container_name: apprise
    image: caronc/apprise
    restart: unless-stopped
    ports:
      - 8000:8000
    environment:
      APPRISE_STATELESS_URLS: tgram://${TELEGRAM_LOGGER_TOKEN}/${TELEGRAM_LOGGER_CHATID}?format=markdown
  ```
