FROM alpine:latest AS build-env

ENV LIBRESSL_VERSION="2.8.2" \
    LIBRESSL_SHA="bfcc55904efbb591c9edd56169d611e735108dfc6a49f771a64ad1ddd028d3a658f5593116c379911edc77f95eba475daec9c0adea0549e8b4b94d1072adf733"

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

ENV UNBOUND_VERSION="1.8.1" \
    UNBOUND_SHA="1872a980e06258d28d2bc7f69a4c56fc07e03e4c9856161e89abc28527fff5812a47ea9927fd362bca690e3a87b95046ac96c8beeccaeb8596458f140c33b217"

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
    AR="gcc-ar" RANLIB="gcc-ranlib" ./configure --prefix=/opt/unbound --with-pthreads \
        --with-username=unbound --with-ssl=/opt/libressl --with-libevent \
        --enable-event-api --enable-static=no ; \
    make -j$(getconf _NPROCESSORS_ONLN); \
    make install; \
    curl -s ftp://FTP.INTERNIC.NET/domain/named.cache -o /opt/unbound/etc/unbound/root.hints; \
    rm /opt/unbound/etc/unbound/unbound.conf

RUN set -ex ; \
    rm -fr /opt/libressl/share; \
    rm -fr /opt/libressl/include/*;  \
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

RUN set -ex; \
    apk add --no-cache libevent expat; \
    addgroup -g 59834 -S unbound 2>/dev/null; \
    adduser -S -D -H -u 59834 -h /etc/unbound -s /sbin/nologin -G unbound -g "Unbound user" unbound 2>/dev/null; \
    mkdir -p /opt/unbound/etc/unbound/unbound.conf.d; \
    mkdir -p /var/log/unbound && chown unbound.unbound /var/log/unbound; \
    rm -rf /usr/share/docs/* /usr/share/man/* /var/log/*

COPY resources/unbound.sh /

RUN chmod +x /unbound.sh

COPY resources/unbound.conf /opt/unbound/etc/unbound/
COPY resources/allow.conf /opt/unbound/etc/unbound/unbound.conf.d/

EXPOSE 53/udp

CMD ["/unbound.sh"]
