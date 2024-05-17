FROM ubuntu:20.04
LABEL maintainer="Past2l <yundohyun050121@gmail.com>"
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Seoul \
  UID=1000 \
  GID=1000 \
  RAM=4096M \
  VERSION=latest \
  TYPE=paper \
  SERVER_DIRECTORY=/app \
  LIBRARY_DIRECTORY=/lib
WORKDIR $SERVER_DIRECTORY
RUN apt-get update
RUN apt-get install -y curl sudo
COPY server $SERVER_DIRECTORY
RUN chmod +x server
ENTRYPOINT ./server -v $VERSION -t $TYPE -r $RAM -d $SERVER_DIRECTORY -ld $LIBRARY_DIRECTORY
