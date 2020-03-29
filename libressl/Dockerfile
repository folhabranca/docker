FROM alpine:3.11 AS build-env

ARG LIBRESSL_VERSION="3.0.2"

RUN LIBRESSL_DOWNLOAD_URL="https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VERSION}.tar.gz"; \
    LIBRESSL_KEY="A1EB079B8D3EB92B4EBD3139663AF51BD5E4D8D5"; \
    BUILD_DEPS='build-base curl file gnupg linux-headers'; \
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
    ./configure --prefix=/opt/libressl; \
    make -j$(getconf _NPROCESSORS_ONLN); \
    make install; \
    rm -rf /usr/local/share/man;

# ----------------------------------------------------------------------------

FROM alpine:3.11

COPY --from=build-env /opt /opt
