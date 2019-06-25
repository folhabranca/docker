FROM alpine:3.10 AS build-env

ARG LIBRESSL_VERSION="2.9.2"

RUN LIBRESSL_DOWNLOAD_URL="https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VERSION}.tar.gz"; \
    LIBRESSL_KEY="A1EB079B8D3EB92B4EBD3139663AF51BD5E4D8D5"; \
    BUILD_DEPS='build-base curl file gnupg linux-headers sed'; \
    set -ex; \
    apk add --no-cache $BUILD_DEPS; \
    mkdir -p /tmp/src/libressl; \
    cd /tmp/src; \
    curl -sSL ${LIBRESSL_DOWNLOAD_URL} -o libressl.tar.gz; \
    curl -sSL ${LIBRESSL_DOWNLOAD_URL}.asc -o libressl.tar.gz.asc; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "${LIBRESSL_KEY}" \
    || gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "${LIBRESSL_KEY}" \
    || gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "${LIBRESSL_KEY}"; \
    gpg --batch --verify libressl.tar.gz.asc libressl.tar.gz; \
    cd libressl; \
    tar xzf ../libressl.tar.gz --strip-components=1; \
    rm -f ../libressl.tar.gz*; \
    CFLAGS="-DLIBRESSL_APPS=off -DLIBRESSL_TESTS=off"; \
    # Fix libressl build with musl libc
    sed -i "s/#if defined(__ANDROID_API__) && __ANDROID_API__ < 21/#if 1/" ./crypto/compat/getprogname_linux.c; \
    # Build without static enabled is not working with 2.9
#    ./configure --prefix=/opt/libressl --enable-static=no; \
    ./configure --prefix=/opt/libressl; \
    make -j$(getconf _NPROCESSORS_ONLN); \
    make install

ARG UNBOUND_VERSION="1.9.2"

RUN UNBOUND_DOWNLOAD_URL="https://www.unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz"; \
    UNBOUND_KEY="EDFAA3F2CA4E6EB05681AF8E9F6F1C2D7E045F8D"; \
    BUILD_DEPS='build-base curl file gnupg linux-headers'; \
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
    curl -sSL $UNBOUND_DOWNLOAD_URL.asc -o unbound.tar.gz.asc; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "${UNBOUND_KEY}" \
    || gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "${UNBOUND_KEY}" \
    || gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "${UNBOUND_KEY}"; \
    gpg --batch --verify unbound.tar.gz.asc unbound.tar.gz; \
    cd unbound; \
    tar xzf ../unbound.tar.gz --strip-components=1; \
    rm -f ../unbound.tar.gz*; \
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
    rm -fr /opt/libressl/lib/*.la /opt/libressl/lib/*.a;  \
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

FROM alpine:3.10

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
    chmod 600 /opt/unbound/etc/unbound/root.key; \
    rm -rf /usr/share/docs/* /usr/share/man/* /var/log/*

EXPOSE 53/udp

CMD ["/unbound.sh"]