FROM alpine:latest AS build-env

ENV LIBRESSL_VERSION="2.8.3" \
    LIBRESSL_SHA="3967e08b3dc2277bf77057ea1f11148df7f96a2203cd21cf841902f2a1ec11320384a001d01fa58154d35612f7981bf89d5b1a60a2387713d5657677f76cc682"

RUN BUILD_DEPS='build-base curl file linux-headers'; \
    LIBRESSL_DOWNLOAD_URL="https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VERSION}.tar.gz"; \
    set -ex; \
    apk add --no-cache $BUILD_DEPS; \
    mkdir -p /tmp/src/libressl; \
    cd /tmp/src; \
    curl -sSL $LIBRESSL_DOWNLOAD_URL -o libressl.tar.gz; \
    echo "${LIBRESSL_SHA} *libressl.tar.gz" | sha512sum -c - ; \
    cd libressl; \
    tar xzf ../libressl.tar.gz --strip-components=1; \
    rm -f ../libressl.tar.gz; \
    CFLAGS="-DLIBRESSL_APPS=off -DLIBRESSL_TESTS=off"; \
    ./configure --prefix=/opt/libressl --enable-static=no; \
    make -j$(getconf _NPROCESSORS_ONLN); \
    make install

ENV UNBOUND_VERSION="1.9.1" \
    UNBOUND_SHA="5dfac7ce3892f73109fdfe0f81863643b1f4c10cee2d4e2d1a28132f1b9ea4d4f89242e4e6348fdadf998f1c75d53577cbf4f719e98faa1342fc3c5de2e8903d"

RUN BUILD_DEPS='build-base curl file linux-headers';  \
    UNBOUND_DOWNLOAD_URL="https://www.unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz"; \
    set -ex; \
    apk add --no-cache \
      $BUILD_DEPS  \
      libevent  \
      libevent-dev  \
      expat   \
      expat-dev; \
    mkdir -p /tmp/src/unbound; \
    cd /tmp/src; \
    curl -sSL $UNBOUND_DOWNLOAD_URL -o unbound.tar.gz; \
    echo "${UNBOUND_SHA} *unbound.tar.gz" | sha512sum -c - ; \
    cd unbound; \
    tar xzf ../unbound.tar.gz --strip-components=1; \
    rm -f ../unbound.tar.gz; \
    addgroup -S unbound 2>/dev/null; \
    adduser -S -D -H -h /etc/unbound -s /sbin/nologin -G unbound -g "Unbound user" unbound 2>/dev/null; \
    RANLIB="gcc-ranlib" ./configure --prefix=/opt/unbound --with-pthreads \
        --with-username=unbound --with-ssl=/opt/libressl --with-libevent \
        --enable-event-api --enable-static=no --enable-pie  --enable-relro-now;  \
    make -j$(getconf _NPROCESSORS_ONLN); \
    mkdir -p /opt/unbound/etc/unbound/unbound.conf.d; \
    make install; \
    curl -s ftp://FTP.INTERNIC.NET/domain/named.cache -o /opt/unbound/etc/unbound/root.hints; \
    /opt/unbound/sbin/unbound-anchor -v  -a /opt/unbound/etc/unbound/root.key || true; \
    rm /opt/unbound/etc/unbound/unbound.conf

RUN set -ex ; \
    rm -fr /opt/libressl/share; \
    rm -fr /opt/libressl/include/*;  \
    rm -fr /opt/libressl/lib/libtls.* /opt/libressl/bin/ocspcheck;  \
    rm -fr /opt/libressl/lib/pkgconfig;  \
    rm -fr /opt/unbound/lib/pkgconfig;  \
    rm /opt/libressl/lib/*.la;  \
    rm -fr /opt/unbound/share /opt/unbound/include /opt/unbound/lib/*.la; \
    find /opt/libressl/bin -type f | xargs strip --strip-all; \
    find /opt/libressl/lib/lib* -type f | xargs strip --strip-all; \
    find /opt/unbound/lib/lib* -type f | xargs strip --strip-all; \
    strip --strip-all /opt/unbound/sbin/unbound; \
    strip --strip-all /opt/unbound/sbin/unbound-anchor; \
    strip --strip-all /opt/unbound/sbin/unbound-checkconf;  \
    strip --strip-all /opt/unbound/sbin/unbound-control; \
    strip --strip-all /opt/unbound/sbin/unbound-host

# ----------------------------------------------------------------------------

FROM alpine:latest

COPY --from=build-env /opt/ /opt/

COPY resources/unbound.sh /
COPY resources/unbound.conf /opt/unbound/etc/unbound/
COPY resources/allow.conf /opt/unbound/etc/unbound/unbound.conf.d/

RUN set -ex; \
    apk add --no-cache libevent expat; \
    addgroup -g 59834 -S unbound 2>/dev/null; \
    adduser -S -D -H -u 59834 -h /etc/unbound -s /sbin/nologin -G unbound -g "Unbound user" unbound 2>/dev/null; \
    mkdir -p /var/log/unbound && chown unbound.unbound /var/log/unbound; \
    chmod +x /unbound.sh; \
    chown unbound.unbound /opt/unbound/etc/unbound/root.key; \
    rm -rf /usr/share/docs/* /usr/share/man/* /var/log/*

EXPOSE 53/udp

CMD ["/unbound.sh"]
