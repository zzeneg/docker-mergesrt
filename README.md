# docker-mergesrt
Fork of zzeneg/mergesrt. Docker container for monitoring subtitle files and merging them into video

   Published on [Docker Hub townsste](https://hub.docker.com/r/townsste/mergesrt)

   Published on [Docker Hub zzeneg](https://hub.docker.com/r/zzeneg/mergesrt)

## Features
- search for existing `*.lang.srt` files
- search for existing with tags (sdh, forced, hi, cc) `*.tag.lang.srt` files
- monitor for new `*.lang.srt` files
- merge subtitles to `mkv`/`mp4` files
- replace existing subtitles with the same language
- remove merged `*.lang.srt` files
- send notification to a webhook after a merge (success/fail)

## Added functionality
- Use 2 language code.
- Supports tags with sdh, forced, hi, & cc.
- Supports merging .idx with .sub file.

## Subtitle Format:
     file_name.TAG.LANGUAGE.srt
     file_name.LANGUAGE.srt

- Example:
     - SRT
          - file_name.sdh.en.srt
          - file_name.forced.eng.srt.
          - file_name.eng.srt 
          - file_name.en.srt

    - IDX
         - file_name.idx

## Requirements
- A folder with media files should be mapped to `/data`
- SRT file should have a language in its name in [ISO 639-1](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) or [ISO 639-2](https://en.wikipedia.org/wiki/List_of_ISO_639-2_codes) format, e.g. `name.en.srt` or `name.eng.srt`.
- For IDX a `.sub` file should be placed in the same directory as the `.idx` and `video file`.

## Usage
- specify environment variables for a webhook (optional):
  - `WEBHOOK_URL` - URL for the POST request. For example you can use [Apprise](https://github.com/caronc/apprise)
  - `WEBHOOK_TEMPLATE` - template for the POST request body. Note that all double quotes `"` should be escaped by a backslash `\` and dollar signs `$` should be doubled. You can use variables in this template:
    - `$SRT_FILE` - full path to the subtitle file
    - `$VIDEO_FILE` - full path to the video file
    - `$LANG` - ISO 639-2 language code of the subtitles 
    - `$RESULT` - merge result, returns `merge succeeded`, `merge completed with warnings` or `merge failed`

- docker-compose example
     - A logo for the docker can be [found here](https://raw.githubusercontent.com/townsste/docker-templates/master/townsste/images/mergesrt.png)
 
  ```yaml
  mergesrt:
    container_name: mergesrt
    image: townsste/mergesrt
    restart: unless-stopped
    environment:
      WEBHOOK_URL: http://apprise:8000/notify
      WEBHOOK_TEMPLATE: '{\"title\":\"*MergeSRT - $$RESULT*\", \"body\":\"$$SRT_FILE\"}'
    volumes:
      - /media:/data
  ```
      
