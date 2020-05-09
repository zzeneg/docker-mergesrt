FROM alpine

RUN apk add --no-cache inotify-tools mkvtoolnix curl jq

COPY /mergesrt.sh /

RUN ["chmod", "+x", "mergesrt.sh"]

ENTRYPOINT ["./mergesrt.sh"]