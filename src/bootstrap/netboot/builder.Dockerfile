FROM ubuntu

RUN  apt-get update \
  && apt-get install -y wget unzip xz-utils zstd tar rsync

WORKDIR /mnt/netboot
CMD [ "bash", "/mnt/netboot/scripts/build-image.sh" ]