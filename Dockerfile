FROM ubuntu:hirsute AS build

RUN \
  apt-get -qq update && \
  apt-get -qq install ldc gcc dub zlib1g-dev libssl-dev && \
  rm -rf /var/lib/apt/lists/*

COPY dd-dice /tmp

WORKDIR /tmp

RUN dub -v build

FROM ubuntu:hirsute
ENV DEBIAN_FRONTEND=noninteractive 

RUN \
  apt-get -qq update && \
  apt-get -qq install libphobos2-ldc-shared-dev zlib1g libssl1.1 && \
  rm -rf /var/lib/apt/lists/*

COPY --from=build /tmp/dd-dice /


RUN apt-get -qq update && apt-get -qq install python3 python3-pip

COPY dicetron/dicetron /
COPY dicetron/requirements.txt /
RUN python3 -m pip install -r /requirements.txt


USER nobody
ENV DD_DICE_PATH="/dd-dice"
#ENV DD_DISCORD_API_TOKEN

ENTRYPOINT ["/dicetron"]