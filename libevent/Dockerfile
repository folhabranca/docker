FROM folhabranca/libressl:latest AS build-env

ARG LIBEVENT_VERSION="2.1.11"

RUN LIBREVENT_DOWNLOAD_URL="https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}-stable/libevent-${LIBEVENT_VERSION}-stable.tar.gz"; \
    LIBEVENT_KEY="9E3AC83A27974B84D1B3401DB86086848EF8686D"; \
    BUILD_DEPS='build-base curl file gnupg linux-headers zlib-dev python2'; \
    set -ex; \
    apk add --no-cache $BUILD_DEPS; \
    mkdir -p /tmp/src/libevent; \
    cd /tmp/src; \
    curl -sSL ${LIBREVENT_DOWNLOAD_URL} -o libevent.tar.gz; \
    curl -sSL ${LIBREVENT_DOWNLOAD_URL}.asc -o libevent.tar.gz.asc; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "${LIBEVENT_KEY}" \
    || gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "${LIBEVENT_KEY}" \
    || gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "${LIBEVENT_KEY}"; \
    gpg --batch --verify libevent.tar.gz.asc libevent.tar.gz; \
    cd libevent; \
    tar xzf ../libevent.tar.gz --strip-components=1; \
    rm -f ../libevent.tar.gz*; \
    env CPPFLAGS='-I/opt/libressl/include' LDFLAGS='-L/opt/libressl/lib/' \
    ./configure --prefix=/opt/libevent \
                --disable-static \
                --disable-libevent-regress \
                --disable-samples \
                --disable-debug-mode \
                --enable-gcc-hardening; \
    make -j$(getconf _NPROCESSORS_ONLN); \
    make install;

# ----------------------------------------------------------------------------

FROM alpine:3.10

COPY --from=build-env /opt /opt

