FROM ubuntu:latest
RUN mkdir /usr/local/at
RUN mkdir /atsign
WORKDIR /usr/local/at
COPY bin/directory .
COPY web web/
WORKDIR /usr/local/at
ENTRYPOINT ["/usr/local/at/directory"]
