FROM kozea/python:hydra-psql 

# ██████   ██████  ███████ ████████  ██████  ██████  ███████ ███████
# ██   ██ ██    ██ ██         ██    ██       ██   ██ ██      ██
# ██████  ██    ██ ███████    ██    ██   ███ ██████  █████   ███████
# ██      ██    ██      ██    ██    ██    ██ ██   ██ ██           ██
# ██       ██████  ███████    ██     ██████  ██   ██ ███████ ███████

# https://hub.docker.com/_/postgres/

ENV PG_MAJOR 12
ENV PG_VERSION 12.8-1.pgdg100+1

# explicitly set user/group IDs
RUN groupadd -r postgres --gid=999 && useradd -r -g postgres --uid=999 postgres

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.12
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US \
	&& localedef -i fr_FR -c -f UTF-8 -A /usr/share/locale/locale.alias fr_FR.UTF-8 \
	&& localedef -i fr_FR -c -f UTF-8 -A /usr/share/locale/locale.alias fr_FR

ENV LANG en_US.utf8

RUN mkdir /docker-entrypoint-initdb.d

RUN set -ex; \
# pub   4096R/ACCC4CF8 2011-10-13 [expires: 2019-07-02]
#       Key fingerprint = B97B 0AFC AA1A 47F0 44F2  44A0 7FCC 7D46 ACCC 4CF8
# uid                  PostgreSQL Debian Repository
	key='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8'; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver  keyserver.ubuntu.com --recv-keys "$key"; \
	gpg --batch --export "$key" > /etc/apt/trusted.gpg.d/postgres.gpg; \
	rm -r "$GNUPGHOME"; \
	apt-key list


RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8

RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main' $PG_MAJOR > /etc/apt/sources.list.d/pgdg.list

# postgresql-contrib isn't already available for postgresql 10
# RUN apt-get update \
#	&& apt-get install -y postgresql-server-dev-all postgresql-common \
#	&& apt-get install -y \
#		postgresql-$PG_MAJOR=$PG_VERSION \
#		postgresql-contrib-$PG_MAJOR=$PG_VERSION \
#	&& rm -rf /var/lib/apt/lists/*

RUN apt-get update \
	&& apt-get install -y postgresql-server-dev-all postgresql-common \
	&& apt-get install -y postgresql-$PG_MAJOR \
	&& rm -rf /var/lib/apt/lists/*


# make the sample config easier to munge (and "correct by default")
RUN set -eux; \
	dpkg-divert --add --rename --divert "/usr/share/postgresql/postgresql.conf.sample.dpkg" "/usr/share/postgresql/$PG_MAJOR/postgresql.conf.sample"; \
	cp -v /usr/share/postgresql/postgresql.conf.sample.dpkg /usr/share/postgresql/postgresql.conf.sample; \
	ln -sv ../postgresql.conf.sample "/usr/share/postgresql/$PG_MAJOR/"; \
	sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql/postgresql.conf.sample; \
	grep -F "listen_addresses = '*'" /usr/share/postgresql/postgresql.conf.sample

RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql

ENV PATH /usr/lib/postgresql/$PG_MAJOR/bin:$PATH



# ███    ███ ██    ██ ██   ████████ ██  ██████  ██████  ██████  ███    ██
# ████  ████ ██    ██ ██      ██    ██ ██      ██    ██ ██   ██ ████   ██
# ██ ████ ██ ██    ██ ██      ██    ██ ██      ██    ██ ██████  ██ ██  ██
# ██  ██  ██ ██    ██ ██      ██    ██ ██      ██    ██ ██   ██ ██  ██ ██
# ██      ██  ██████  ███████ ██    ██  ██████  ██████  ██   ██ ██   ████


ENV MULTICORN_VERSION 1.3.4

# RUN pip install --upgrade setuptools

RUN apt-get update && apt-get install -y --no-install-recommends unzip \
		&& curl -SLO "https://github.com/Segfault-Inc/Multicorn/archive/master.zip" \
		&& mkdir -p /usr/src/multicorn \
		&& unzip master.zip -d /usr/src/multicorn \
		&& rm -fr master.zip \
		&& cd /usr/src/multicorn/Multicorn-master \
		&& env PYTHON_OVERRIDE=/usr/local/bin/python make \
		&& env PYTHON_OVERRIDE=/usr/local/bin/python make install \
		&& rm -fr /usr/src/multicorn \
		&& cd \
		&& apt-get purge -y --auto-remove unzip


###### Bonus virtualenv, lxml/docutils and pipenv
RUN pip install "virtualenv<20.0.0" lxml docutils pipenv

###### Postgresql settings for local run

# RUN /bin/bash -c "echo -e 'local all hydra_secure md5\nlocal all hydra_test_secure md5\nlocal all all trust\nhost all hydra_secure 127.0.0.1/32 md5\nhost all hydra_test_secure 127.0.0.1/32 md5\nhost all all 172.17.0.1/32 trust\nhost all hydra_secure ::1/128 md5\nhost all hydra_test_secure ::1/128 md5\nhost all all ::1/128 trust\n' > /etc/postgresql/12/main/pg_hba.conf"
COPY ./config/pg_hba.conf /etc/postgresql/12/main
COPY ./config/postgresql.conf /etc/postgresql/12/main

# RUN sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/12/main/postgresql.conf

CMD ["/bin/sh", "-c", "/etc/init.d/postgresql start; tail -f /var/log/postgresql/postgresql-12-main.log"]

