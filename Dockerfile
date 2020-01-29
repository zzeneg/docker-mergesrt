FROM alpine

RUN apk add --no-cache inotify-tools mkvtoolnix bash

ADD mergesrt.sh .

RUN ["chmod", "+x", "mergesrt.sh"]

ENTRYPOINT ["./mergesrt.sh"]