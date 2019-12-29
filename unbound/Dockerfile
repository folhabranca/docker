FROM folhabranca/libevent:latest AS build-env

ARG UNBOUND_VERSION="1.9.6"

RUN UNBOUND_DOWNLOAD_URL="https://www.unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz"; \
    UNBOUND_KEYS="EDFAA3F2CA4E6EB05681AF8E9F6F1C2D7E045F8D 21615A7F2478EA8C27DD26B830918D8275724222"; \
    INTERNIC_KEY="F0CB1A326BDF3F3EFA3A01FA937BB869E3A238C5"; \
    BUILD_DEPS='build-base curl file gnupg linux-headers'; \
    set -ex; \
    apk add --no-cache \
      $BUILD_DEPS  \
      expat   \
      expat-dev; \
    mkdir -p /tmp/src/unbound; \
    cd /tmp/src; \
    curl -sSL ${UNBOUND_DOWNLOAD_URL} -o unbound.tar.gz; \
    curl -sSL ${UNBOUND_DOWNLOAD_URL}.asc -o unbound.tar.gz.asc; \
    export GNUPGHOME="$(mktemp -d)"; \
    for UNBOUND_KEY in ${UNBOUND_KEYS}; do \
      gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "${UNBOUND_KEY}" \
      || gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "${UNBOUND_KEY}" \
      || gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "${UNBOUND_KEY}"; \
    done; \
    gpg --batch --verify unbound.tar.gz.asc unbound.tar.gz; \
    cd unbound; \
    tar xzf ../unbound.tar.gz --strip-components=1; \
    rm -f ../unbound.tar.gz*; \
    addgroup -S unbound 2>/dev/null; \
    adduser -S -D -H -h /etc/unbound -s /sbin/nologin -G unbound -g "Unbound user" unbound 2>/dev/null; \
    RANLIB="gcc-ranlib" ./configure --prefix=/opt/unbound --with-pthreads \
        --with-username=unbound --with-ssl=/opt/libressl --with-libevent=/opt/libevent \
        --enable-event-api --enable-static=no --enable-pie  --enable-relro-now;  \
    make -j$(getconf _NPROCESSORS_ONLN); \
    mkdir -p /opt/unbound/etc/unbound/unbound.conf.d; \
    make install; \
    curl -s https://www.internic.net/domain/named.cache -o /opt/unbound/etc/unbound/root.hints; \
    curl -s https://www.internic.net/domain/named.cache.md5 -o /opt/unbound/etc/unbound/root.hints.md5; \
    curl -s https://www.internic.net/domain/named.cache.sig -o /opt/unbound/etc/unbound/root.hints.sig; \
    NAMED_MD5=`cat /opt/unbound/etc/unbound/root.hints.md5`; \
    echo "${NAMED_MD5} */opt/unbound/etc/unbound/root.hints" | md5sum -c - ; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "${INTERNIC_KEY}" \
    || gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "${INTERNIC_KEY}" \
    || gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "${INTERNIC_KEY}"; \
    gpg --verify /opt/unbound/etc/unbound/root.hints.sig /opt/unbound/etc/unbound/root.hints; \
    /opt/unbound/sbin/unbound-anchor -v  -a /opt/unbound/etc/unbound/root.key || true; \
    rm /opt/unbound/etc/unbound/unbound.conf /opt/unbound/etc/unbound/root.hints.md5 /opt/unbound/etc/unbound/root.hints.sig;

RUN set -ex ; \
    rm -fr /opt/libressl/share; \
    rm -fr /opt/libressl/include;  \
    rm -fr /opt/libressl/lib/libtls.* /opt/libressl/bin/ocspcheck;  \
    rm -fr /opt/libressl/lib/pkgconfig;  \
    rm -fr /opt/unbound/lib/pkgconfig;  \
    rm -fr /opt/libressl/lib/*.la /opt/libressl/lib/*.a; \
    rm -fr /opt/libevent/lib/*.la /opt/libevent/bin /opt/libevent/include; \
    rm -fr /opt/libevent/lib/pkgconfig; \
    rm -fr /opt/unbound/share /opt/unbound/include /opt/unbound/lib/*.la; \
    find /opt/libressl/bin -type f | xargs strip --strip-all; \
    find /opt/libressl/lib/lib* -type f | xargs strip --strip-all; \
    find /opt/libevent/lib/lib* -type f | xargs strip --strip-all; \
    find /opt/unbound/lib/lib* -type f | xargs strip --strip-all; \
    strip --strip-all /opt/unbound/sbin/unbound; \
    strip --strip-all /opt/unbound/sbin/unbound-anchor; \
    strip --strip-all /opt/unbound/sbin/unbound-checkconf;  \
    strip --strip-all /opt/unbound/sbin/unbound-control; \
    strip --strip-all /opt/unbound/sbin/unbound-host;

# ----------------------------------------------------------------------------

FROM alpine:3.11

COPY --from=build-env /opt/ /opt/

COPY resources/unbound.sh /
COPY resources/unbound.conf /opt/unbound/etc/unbound/
COPY resources/allow.conf /opt/unbound/etc/unbound/unbound.conf.d/

RUN set -ex; \
    apk add --no-cache expat; \
    apk del --no-cache libevent; \
    addgroup -g 59834 -S unbound 2>/dev/null; \
    adduser -S -D -H -u 59834 -h /etc/unbound -s /sbin/nologin -G unbound -g "Unbound user" unbound 2>/dev/null; \
    mkdir -p /var/log/unbound && chown unbound.unbound /var/log/unbound; \
    chmod +x /unbound.sh; \
    chown unbound.unbound /opt/unbound/etc/unbound/root.key; \
    chmod 600 /opt/unbound/etc/unbound/root.key; \
    rm -rf /usr/share/docs/* /usr/share/man/* /var/log/*

EXPOSE 53/udp

CMD ["/unbound.sh"]