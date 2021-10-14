# ███    ██  ██████  ██████  ███████
# ████   ██ ██    ██ ██   ██ ██
# ██ ██  ██ ██    ██ ██   ██ █████
# ██  ██ ██ ██    ██ ██   ██ ██
# ██   ████  ██████  ██████  ███████

# https://hub.docker.com/_/node/

FROM buildpack-deps:buster

ENV NODE_VERSION 16.6.2
ENV YARN_VERSION 1.22.5

RUN groupadd --gid 1000 node \
  && useradd --uid 1000 --gid node --shell /bin/bash --create-home node

# gpg keys listed at https://github.com/nodejs/node
RUN set -ex \
  && for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    74F12602B6F1C4E913FAA37AD3A89613643B6201 \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
      gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
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
