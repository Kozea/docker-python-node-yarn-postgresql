FROM buildpack-deps:buster

# ██████  ██    ██ ████████ ██   ██  ██████  ███    ██
# ██   ██  ██  ██     ██    ██   ██ ██    ██ ████   ██
# ██████    ████      ██    ███████ ██    ██ ██ ██  ██
# ██         ██       ██    ██   ██ ██    ██ ██  ██ ██
# ██         ██       ██    ██   ██  ██████  ██   ████

# https://hub.docker.com/_/python/

ENV PYTHON_VERSION 3.8.6
ENV PYTHON_PIP_VERSION 20.2.3


# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
		tcl \
		tk \
	&& rm -rf /var/lib/apt/lists/*

ENV GPG_KEY E3FF2839C048B25C084DEBE9B26995E310250568
# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"

RUN set -ex \
	&& buildDeps=' \
        dpkg-dev \
		tcl-dev \
		tk-dev \
	' \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
	\
	&& wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	&& wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& rm -r "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	\
	&& cd /usr/src/python \
	&& ./configure \
		--enable-loadable-sqlite-extensions \
		--enable-shared \
	&& make -j$(nproc) \
	&& make install \
	&& ldconfig \
	\
# explicit path to "pip3" to ensure distribution-provided "pip3" cannot interfere
	&& if [ ! -e /usr/local/bin/pip3 ]; then : \
		&& wget -O /tmp/get-pip.py 'https://bootstrap.pypa.io/get-pip.py' \
		&& python3 /tmp/get-pip.py "pip==$PYTHON_PIP_VERSION" \
		&& rm /tmp/get-pip.py \
	; fi \
# we use "--force-reinstall" for the case where the version of pip we're trying to install is the same as the version bundled with Python
# ("Requirement already up-to-date: pip==8.1.2 in /usr/local/lib/python3.6/site-packages")
# https://github.com/docker-library/python/pull/143#issuecomment-241032683
	&& pip3 install --no-cache-dir --upgrade --force-reinstall "pip==$PYTHON_PIP_VERSION" \
# then we use "pip list" to ensure we don't have more than one pip version installed
# https://github.com/docker-library/python/pull/100
	&& [ "$(pip list |tac|tac| awk -F '[ ()]+' '$1 == "pip" { print $2; exit }')" = "$PYTHON_PIP_VERSION" ] \
	\
	&& find /usr/local -depth \
		\( \
			\( -type d -a -name test -o -name tests \) \
			-o \
			\( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		\) -exec rm -rf '{}' + \
	&& apt-get purge -y --auto-remove $buildDeps \
	&& rm -rf /usr/src/python ~/.cache

# make some useful symlinks that are expected to exist
RUN cd /usr/local/bin \
	&& ln -s idle3 idle \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python3-config python-config


# ███    ██  ██████  ██████  ███████
# ████   ██ ██    ██ ██   ██ ██
# ██ ██  ██ ██    ██ ██   ██ █████
# ██  ██ ██ ██    ██ ██   ██ ██
# ██   ████  ██████  ██████  ███████

# https://hub.docker.com/_/node/


ENV NODE_VERSION 14.12.0
ENV YARN_VERSION 1.22.5

RUN groupadd --gid 1000 node \
  && useradd --uid 1000 --gid node --shell /bin/bash --create-home node

# gpg keys listed at https://github.com/nodejs/node
RUN set -ex \
  && for key in \
  	4ED778F539E3634C779C87C6D7062848A1AB005C \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key"; \
  done

ENV NPM_CONFIG_LOGLEVEL info

RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

	RUN set -ex \
	  && for key in \
	    6A010C5166006599AA17F08146C2130DFD2497F5 \
	  ; do \
        	gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
        	gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
		gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key"; \
	  done \
	  && curl -fSL -o yarn.js "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-legacy-$YARN_VERSION.js" \
	  && curl -fSL -o yarn.js.asc "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-legacy-$YARN_VERSION.js.asc" \
	  && gpg --batch --verify yarn.js.asc yarn.js \
	  && rm yarn.js.asc \
	  && mv yarn.js /usr/local/bin/yarn \
	  && chmod +x /usr/local/bin/yarn


# ██████   ██████  ███████ ████████  ██████  ██████  ███████ ███████
# ██   ██ ██    ██ ██         ██    ██       ██   ██ ██      ██
# ██████  ██    ██ ███████    ██    ██   ███ ██████  █████   ███████
# ██      ██    ██      ██    ██    ██    ██ ██   ██ ██           ██
# ██       ██████  ███████    ██     ██████  ██   ██ ███████ ███████

# https://hub.docker.com/_/postgres/

ENV PG_MAJOR 12
ENV PG_VERSION 12.4-1.pgdg100+1

# explicitly set user/group IDs
RUN groupadd -r postgres --gid=999 && useradd -r -g postgres --uid=999 postgres

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.12
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
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
	gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
	gpg --batch --export "$key" > /etc/apt/trusted.gpg.d/postgres.gpg; \
	rm -r "$GNUPGHOME"; \
	apt-key list


RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8

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
RUN mv -v /usr/share/postgresql/$PG_MAJOR/postgresql.conf.sample /usr/share/postgresql/ \
	&& ln -sv ../postgresql.conf.sample /usr/share/postgresql/$PG_MAJOR/ \
	&& sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql/postgresql.conf.sample

RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod g+s /var/run/postgresql

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

CMD ["bash"]
