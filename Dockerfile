FROM ubuntu:20.04
LABEL maintainer="Past2l <yundohyun050121@gmail.com>"
LABEL org.opencontainers.image.source https://github.com/past2l/minecraft-server
ARG DEBIAN_FRONTEND=noninteractive
ENV UID=1000 \
  GID=1000 \
  TZ=Asia/Seoul \
  RAM=4096M \
  VERSION=latest \
  TYPE=paper \
  FORCE_REPLACE=false \
  REMAPPED=false \
  SERVER_DIRECTORY=/mc/app \
  LIBRARY_DIRECTORY=/mc/lib
RUN mkdir -p /mc
WORKDIR /mc
RUN apt-get update
RUN apt-get install -y curl sudo
COPY server .
RUN chmod +x server
EXPOSE 25565/tcp
CMD ./server -v $VERSION -t $TYPE -r $RAM \
  -d $SERVER_DIRECTORY -ld $LIBRARY_DIRECTORY \
  $( [ "$FORCE_REPLACE" = "true" ] && echo "--force-replace" || echo "" ) \
  $( [ "$REMAPPED" = "true" ] && echo "--remapped" || echo "" )
