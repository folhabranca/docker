FROM debian:9-slim AS build-env
RUN set -x && \
    apt-get update && apt-get install -y --no-install-recommends \
      bsdmainutils \
      ldnsutils && \
      rm -rf /var/lib/apt/lists/*
ENV LIBRESSL_VERSION="2.6.4" \
    LIBRESSL_SHA256="638a20c2f9e99ee283a841cd787ab4d846d1880e180c4e96904fc327d419d11f" \
    LIBRESSL_DOWNLOAD_URL="https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-2.6.4.tar.gz"
RUN BUILD_DEPS='ca-certificates curl gcc libc-dev make file' && \
    set -x && \
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
      $BUILD_DEPS && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    curl -sSL $LIBRESSL_DOWNLOAD_URL -o libressl.tar.gz && \
    echo "${LIBRESSL_SHA256} *libressl.tar.gz" | sha256sum -c - && \
    tar xzf libressl.tar.gz && \
    rm -f libressl.tar.gz && \
    cd libressl-2.6.4 && \
    AR='gcc-ar' RABLIB='gcc-ranlib' ./configure --disable-dependency-tracking --prefix=/opt/libressl && \
    AR='gcc-ar' RABLIB='gcc-ranlib' make check && make install && \
    echo /opt/libressl/lib > /etc/ld.so.conf.d/libressl.conf && ldconfig
ENV UNBOUND_VERSION="1.6.8" \
    UNBOUND_SHA256="e3b428e33f56a45417107448418865fe08d58e0e7fea199b855515f60884dd49" \
    UNBOUND_DOWNLOAD_URL="https://www.unbound.net/downloads/unbound-1.6.8.tar.gz"
RUN BUILD_DEPS='ca-certificates curl gcc libc-dev make file' && \
    set -x && \
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
      $BUILD_DEPS  \
      libevent-2.0  \
      libevent-dev  \
      libexpat1   \
      libexpat1-dev && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    curl -sSL $UNBOUND_DOWNLOAD_URL -o unbound.tar.gz && \
    echo "${UNBOUND_SHA256} *unbound.tar.gz" | sha256sum -c - && \
    tar xzf unbound.tar.gz && \
    rm -f unbound.tar.gz && \
    cd unbound-1.6.8 && \
    groupadd unbound && \
    useradd -g unbound -s /etc -d /dev/null _unbound && \
    ./configure AR='gcc-ar' RANLIB='gcc-ranlib' --prefix=/opt/unbound --with-pthreads \
        --with-username=unbound --with-ssl=/opt/libressl --with-libevent \
        --enable-event-api && \
    AR='gcc-ar' RANLIB='gcc-ranlib' make install && \
    curl -s ftp://FTP.INTERNIC.NET/domain/named.cache -o /opt/unbound/etc/unbound/root.hints && \
    rm /opt/unbound/etc/unbound/unbound.conf
RUN set -x && \
    rm -fr /opt/libressl/share && \
    rm -fr /opt/libressl/include/* && \
    rm /opt/libressl/lib/*.a /opt/libressl/lib/*.la && \
    rm -fr /opt/unbound/share /opt/unbound/include /opt/unbound/lib/*.a /opt/unbound/lib/*.la && \
    find /opt/libressl/bin -type f | xargs strip --strip-all && \
    find /opt/libressl/lib/lib* -type f | xargs strip --strip-all && \
    find /opt/unbound/lib/lib* -type f | xargs strip --strip-all && \
    strip --strip-all /opt/unbound/sbin/unbound && \
    strip --strip-all /opt/unbound/sbin/unbound-anchor && \
    strip --strip-all /opt/unbound/sbin/unbound-checkconf && \
    strip --strip-all /opt/unbound/sbin/unbound-control && \
    strip --strip-all /opt/unbound/sbin/unbound-host
# ----------------------------------------------------------------------------
FROM debian:9-slim
COPY --from=build-env /opt/ /opt/
RUN set -x && \
    apt-get update && apt-get install -y --no-install-recommends \
      bsdmainutils \
      ldnsutils \
      libevent-2.0 \
      libexpat1 && \
    adduser --disabled-login --disabled-password --shell /bin/false \ 
          -uid 63423 --system --group --home /var/lib/unbound unbound && \
    find /usr -user root -perm -4000 -exec chmod a-s {} \; && \
    mkdir -p /opt/unbound/etc/unbound/unbound.conf.d && \
    mkdir -p /var/log/unbound && chown unbound.unbound /var/log/unbound && \
    rm -rf /var/lib/apt/lists/* /usr/share/docs/* /usr/share/man/* /var/log/*
COPY resources/unbound.sh /
RUN chmod +x /unbound.sh
COPY resources/unbound.conf /opt/unbound/etc/unbound/
COPY resources/allow.conf /opt/unbound/etc/unbound/unbound.conf.d/
EXPOSE 53/udp
CMD ["/unbound.sh"]
