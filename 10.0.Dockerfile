FROM debian:jessie AS base

EXPOSE 8069 8072

ARG GEOIP_UPDATER_VERSION=4.1.5
ARG MQT=https://github.com/OCA/maintainer-quality-tools.git
ARG WKHTMLTOPDF_VERSION=0.12.5
ARG WKHTMLTOPDF_CHECKSUM='2583399a865d7604726da166ee7cec656b87ae0a6016e6bce7571dcd3045f98b'
ENV DB_FILTER=.* \
    DEPTH_DEFAULT=1 \
    DEPTH_MERGE=100 \
    EMAIL=https://hub.docker.com/r/tecnativa/odoo \
    GEOIP_ACCOUNT_ID="" \
    GEOIP_LICENSE_KEY="" \
    GIT_AUTHOR_NAME=docker-odoo \
    INITIAL_LANG="" \
    LC_ALL=C.UTF-8 \
    LIST_DB=false \
    NODE_PATH=/usr/local/lib/node_modules:/usr/lib/node_modules \
    OPENERP_SERVER=/opt/odoo/auto/odoo.conf \
    PATH="/home/odoo/.local/bin:$PATH" \
    PIP_NO_CACHE_DIR=0 \
    PTVSD_ARGS="--host 0.0.0.0 --port 6899 --wait --multiprocess" \
    PTVSD_ENABLE=0 \
    DEBUGPY_ARGS="--listen 0.0.0.0:6899 --wait-for-client" \
    DEBUGPY_ENABLE=0 \
    PUDB_RDB_HOST=0.0.0.0 \
    PUDB_RDB_PORT=6899 \
    PYTHONOPTIMIZE=1 \
    UNACCENT=true \
    WAIT_DB=true \
    WDB_NO_BROWSER_AUTO_OPEN=True \
    WDB_SOCKET_SERVER=wdb \
    WDB_WEB_PORT=1984 \
    WDB_WEB_SERVER=localhost

RUN sed -i 's,http://deb.debian.org,http://archive.debian.org,g;s,http://security.debian.org,http://archive.debian.org,g;s,\(.*jessie-updates\),#\1,' /etc/apt/sources.list

# Other requirements and recommendations to run Odoo
# See https://github.com/$ODOO_SOURCE/blob/$ODOO_VERSION/debian/control
RUN apt-get update
RUN apt-get -y upgrade

RUN apt-get install -y --force-yes --no-install-recommends python ruby-compass \
    fontconfig libfreetype6 libxml2 libxslt1.1 libjpeg62-turbo zlib1g \
    fonts-liberation libfreetype6 liblcms2-2 libopenjpeg5 libtiff5 tk tcl \
    libpq5 libldap-2.4-2 libsasl2-2 libx11-6 libxext6 libxrender1 \
    locales-all zlibc bzip2 ca-certificates curl gettext git nano \
    openssh-client telnet xz-utils apt-transport-https python-dev

RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py | python /dev/stdin

RUN curl -SLO https://deb.nodesource.com/node_6.x/pool/main/n/nodejs/nodejs_6.17.1-1nodesource1_amd64.deb \
 && dpkg -i nodejs_6.17.1-1nodesource1_amd64.deb \
 && apt-get install -f -y \
 && rm nodejs_6.17.1-1nodesource1_amd64.deb


RUN curl -SLo fonts-liberation2.deb \
    http://archive.debian.org/debian/pool/main/f/fonts-liberation2/fonts-liberation2_2.00.1-3_all.deb
RUN dpkg --install fonts-liberation2.deb

RUN curl -SLo wkhtmltox.deb \
    https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}-1.jessie_amd64.deb
RUN echo "${WKHTMLTOPDF_CHECKSUM}  wkhtmltox.deb" | sha256sum -c -
RUN dpkg --install wkhtmltox.deb || true
RUN apt-get install -yqq --force-yes --no-install-recommends --fix-broken

RUN rm fonts-liberation2.deb wkhtmltox.deb
RUN wkhtmltopdf --version

RUN curl --silent -L --output geoipupdate_${GEOIP_UPDATER_VERSION}_linux_amd64.deb \
    https://github.com/maxmind/geoipupdate/releases/download/v${GEOIP_UPDATER_VERSION}/geoipupdate_${GEOIP_UPDATER_VERSION}_linux_amd64.deb
RUN dpkg -i geoipupdate_${GEOIP_UPDATER_VERSION}_linux_amd64.deb
RUN rm geoipupdate_${GEOIP_UPDATER_VERSION}_linux_amd64.deb

RUN rm -Rf /var/lib/apt/lists/*

# Special case to get latest PostgreSQL client in 250-postgres-client
RUN echo 'deb http://apt-archive.postgresql.org/pub/repos/apt/ jessie-pgdg main' >> /etc/apt/sources.list.d/postgresql.list \
    && curl -SL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

RUN ln -s /usr/bin/nodejs /usr/local/bin/node \
    && npm install -g less@2 less-plugin-clean-css@1 phantomjs-prebuilt@2 \
    && rm -Rf ~/.npm /tmp/*

# Special case to get bootstrap-sass, required by Odoo for Sass assets
RUN gem install --no-rdoc --no-ri --no-update-sources execjs --version '<2.9.1' \
    && gem install --no-rdoc --no-ri --no-update-sources autoprefixer-rails --version '<9.8.6' \
    && gem install --no-rdoc --no-ri --no-update-sources bootstrap-sass --version '<3.4' \
    && rm -Rf ~/.gem /var/lib/gems/*/cache/

# Other facilities
WORKDIR /opt/odoo
RUN pip install click-odoo-contrib==1.6.0
RUN pip install "git-aggregator<3.0.0"
RUN pip install plumbum==1.6.9
RUN pip install ptvsd==4.3.2
RUN pip install debugpy==1.0.0b12
RUN pip install pudb==2019.1
RUN pip install virtualenv==16.7.12
RUN pip install wdb==2.0.0
RUN pip install simplejson==3.17.0
RUN pip install geoip2==2.9.0
RUN sync
COPY bin-deprecated/* bin/* /usr/local/bin/
COPY lib/doodbalib /usr/local/lib/python2.7/dist-packages/doodbalib
RUN ln -s /usr/local/lib/python2.7/dist-packages/doodbalib \
    /usr/local/lib/python2.7/dist-packages/odoobaselib
COPY build.d common/build.d
COPY conf.d common/conf.d
COPY entrypoint.d common/entrypoint.d
RUN mkdir -p auto/addons auto/geoip custom/src/private \
    && ln /usr/local/bin/direxec common/entrypoint \
    && ln /usr/local/bin/direxec common/build \
    && chmod -R a+rx common/entrypoint* common/build* /usr/local/bin \
    && chmod -R a+rX /usr/local/lib/python2.7/dist-packages/doodbalib \
    && mv /etc/GeoIP.conf /opt/odoo/auto/geoip/GeoIP.conf \
    && ln -s /opt/odoo/auto/geoip/GeoIP.conf /etc/GeoIP.conf \
    && sed -i 's/.*DatabaseDirectory .*$/DatabaseDirectory \/opt\/odoo\/auto\/geoip\//g' /opt/odoo/auto/geoip/GeoIP.conf \
    && sync

# Doodba-QA dependencies in a separate virtualenv
COPY qa /qa
RUN python -m virtualenv --system-site-packages /qa/venv \
    && . /qa/venv/bin/activate \
    # HACK: Upgrade pip: higher version needed to install pyproject.toml based packages
    && pip install -U pip \
    && pip install --no-cache-dir \
        click \
        coverage \
        flake8 \
        git+https://github.com/OCA/pylint-odoo.git@refs/pull/329/head \
        six \
    && npm install --loglevel error --prefix /qa 'eslint@<6' \
    && deactivate \
    && mkdir -p /qa/artifacts \
    && git clone --depth 1 $MQT /qa/mqt

# Execute installation script by Odoo version
# This is at the end to benefit from cache at build time
# https://docs.docker.com/engine/reference/builder/#/impact-on-build-caching
ARG ODOO_SOURCE=OCA/OCB
ARG ODOO_VERSION=10.0
ENV ODOO_VERSION="$ODOO_VERSION"
# RUN debs="libldap2-dev libsasl2-dev libxml2-dev libxslt1-dev zlib1g-dev build-essential " \
#     && apt-get update \
#     && apt-get install -yqq --force-yes --no-install-recommends $debs \
#     && pip install \
#         -r https://raw.githubusercontent.com/$ODOO_SOURCE/$ODOO_VERSION/requirements.txt \
#     && (python2 -m compileall -q /usr/local/lib/python2.7/ || true) \
#     && apt-get purge -yqq $debs \
#     && rm -Rf /var/lib/apt/lists/* /tmp/*
RUN install.sh
RUN pip install pg_activity
# Metadata
ARG VCS_REF
ARG BUILD_DATE
ARG VERSION
LABEL org.label-schema.schema-version="$VERSION" \
      org.label-schema.vendor=Tecnativa \
      org.label-schema.license=Apache-2.0 \
      org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.vcs-ref="$VCS_REF" \
      org.label-schema.vcs-url="https://github.com/Tecnativa/doodba"

# Onbuild version, with all the magic
FROM base AS onbuild

# Subimage triggers
ONBUILD USER root
ONBUILD ENTRYPOINT ["/opt/odoo/common/entrypoint"]
ONBUILD CMD ["/usr/local/bin/odoo"]
ONBUILD ARG AGGREGATE=true
ONBUILD ARG DEFAULT_REPO_PATTERN="https://github.com/OCA/{}.git"
ONBUILD ARG DEFAULT_REPO_PATTERN_ODOO="https://github.com/OCA/OCB.git"
ONBUILD ARG DEPTH_DEFAULT=1
ONBUILD ARG DEPTH_MERGE=100
ONBUILD ARG CLEAN=true
ONBUILD ARG COMPILE=true
ONBUILD ARG FONT_MONO="Liberation Mono"
ONBUILD ARG FONT_SANS="Liberation Sans"
ONBUILD ARG FONT_SERIF="Liberation Serif"
ONBUILD ARG PIP_INSTALL_ODOO=true
ONBUILD ARG ADMIN_PASSWORD=admin
ONBUILD ARG SMTP_SERVER=smtp
ONBUILD ARG SMTP_PORT=25
ONBUILD ARG SMTP_USER=false
ONBUILD ARG SMTP_PASSWORD=false
ONBUILD ARG SMTP_SSL=false
ONBUILD ARG EMAIL_FROM=""
ONBUILD ARG PROXY_MODE=false
ONBUILD ARG WITHOUT_DEMO=all
ONBUILD ARG PGUSER=odoo
ONBUILD ARG PGPASSWORD=odoopassword
ONBUILD ARG PGHOST=db
ONBUILD ARG PGPORT=5432
ONBUILD ARG PGDATABASE=prod
# Config variables
ONBUILD ENV ADMIN_PASSWORD="$ADMIN_PASSWORD" \
            DEFAULT_REPO_PATTERN="$DEFAULT_REPO_PATTERN" \
            DEFAULT_REPO_PATTERN_ODOO="$DEFAULT_REPO_PATTERN_ODOO" \
            UNACCENT="$UNACCENT" \
            PGUSER="$PGUSER" \
            PGPASSWORD="$PGPASSWORD" \
            PGHOST="$PGHOST" \
            PGPORT=$PGPORT \
            PGDATABASE="$PGDATABASE" \
            PROXY_MODE="$PROXY_MODE" \
            SMTP_SERVER="$SMTP_SERVER" \
            SMTP_PORT=$SMTP_PORT \
            SMTP_USER="$SMTP_USER" \
            SMTP_PASSWORD="$SMTP_PASSWORD" \
            SMTP_SSL="$SMTP_SSL" \
            EMAIL_FROM="$EMAIL_FROM" \
            WITHOUT_DEMO="$WITHOUT_DEMO"
ONBUILD ARG LOCAL_CUSTOM_DIR=./custom
ONBUILD COPY $LOCAL_CUSTOM_DIR /opt/odoo/custom

# Enable setting custom uids for odoo user during build of scaffolds
ONBUILD ARG UID=1000
ONBUILD ARG GID=1000

# Enable Odoo user and filestore
ONBUILD RUN groupadd -g $GID odoo -o \
    && useradd -l -md /home/odoo -s /bin/false -u $UID -g $GID odoo \
    && mkdir -p /var/lib/odoo \
    && chown -R odoo:odoo /var/lib/odoo /qa/artifacts\
    && chmod a=rwX /qa/artifacts \
    && sync

# https://docs.python.org/2.7/library/logging.html#levels
ONBUILD ARG LOG_LEVEL=INFO
ONBUILD RUN mkdir -p /opt/odoo/custom/ssh \
            && ln -s /opt/odoo/custom/ssh ~root/.ssh \
            && chmod -R u=rwX,go= /opt/odoo/custom/ssh \
            && sync
ONBUILD ARG DB_VERSION=latest
ONBUILD RUN echo "$PYTHONPATH"
ONBUILD RUN /opt/odoo/common/build && sync
ONBUILD VOLUME ["/var/lib/odoo"]
ONBUILD USER odoo
# HACK Special case for Werkzeug
ONBUILD RUN pip install --user Werkzeug==0.14.1
