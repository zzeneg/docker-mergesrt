FROM alpine

RUN apk add --no-cache inotify-tools mkvtoolnix curl

COPY /mergesrt.sh /

RUN ["chmod", "+x", "mergesrt.sh"]

ENTRYPOINT ["./mergesrt.sh"]