FROM postgres:12

LABEL maintainer="JamesClonk <jamesclonk@jamesclonk.ch>"

# add additional packages
RUN apt-get -y update \
  && apt-get -y install unzip zlibc openssl zip curl wget ca-certificates netcat \
  && apt-get autoremove -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# install minio client CLI
RUN wget 'https://dl.minio.io/client/mc/release/linux-amd64/mc' \
  && mv mc /usr/local/bin/mc \
  && chmod 755 /usr/local/bin/mc

# create backup user
RUN useradd -u 2000 -mU -s /bin/bash pgbackup && \
  mkdir /home/pgbackup/app && \
  chown pgbackup:pgbackup /home/pgbackup/app

# add backup script
WORKDIR /home/pgbackup/app
COPY backup.sh ./

RUN chmod u+x /home/pgbackup/app/backup.sh
RUN chown -R pgbackup:pgbackup /home/pgbackup/app
USER pgbackup

CMD ["/home/pgbackup/app/backup.sh"]
