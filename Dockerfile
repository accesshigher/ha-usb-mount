
FROM alpine:3.18
RUN apk add --no-cache e2fsprogs util-linux jq blkid
COPY run.sh /run.sh
RUN chmod +x /run.sh
CMD ["/run.sh"]
