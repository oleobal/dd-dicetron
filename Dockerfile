FROM debian:bookworm AS build
ENV DEBIAN_FRONTEND=noninteractive 

RUN \
  apt-get -qq update && \
  apt-get -qq install ldc gcc dub zlib1g-dev libssl-dev && \
  rm -rf /var/lib/apt/lists/*

COPY dd-dice /tmp

WORKDIR /tmp


RUN dub -v build -b release

FROM node:21-bookworm

RUN \
  apt-get -qq update && \
  apt-get -qq install libphobos2-ldc-shared-dev zlib1g libssl3 && \
  rm -rf /var/lib/apt/lists/*

COPY --from=build /tmp/dd-dice /
ENV DD_DICE_PATH="/dd-dice"

COPY dicetron /dicetron
WORKDIR dicetron
RUN npm install

COPY dd-dice/modules /dd-modules
ENV DD_MODULES_PATH="/dd-modules"

ENV PORT=80

ENTRYPOINT ["/dicetron/start.sh"]