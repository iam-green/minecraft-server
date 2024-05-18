FROM ubuntu:20.04
LABEL maintainer="Past2l <yundohyun050121@gmail.com>"
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Seoul \
  UID=1000 \
  GID=1000 \
  RAM=4096M \
  VERSION=latest \
  TYPE=paper \
  SERVER_DIRECTORY=/mc/app \
  LIBRARY_DIRECTORY=/mc/lib
RUN mkdir -p /mc
WORKDIR /mc
RUN apt-get update
RUN apt-get install -y curl sudo
COPY server .
RUN chmod +x server
CMD ./server -v $VERSION -t $TYPE -r $RAM -d $SERVER_DIRECTORY -ld $LIBRARY_DIRECTORY
