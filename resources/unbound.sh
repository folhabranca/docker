#! /bin/sh

PATH=$PATH:/opt/libressl/bin

PORT=${PORT:-53}
DO_IPV6=${DO_IPV6:-yes}
DO_IPV4=${DO_IPV4:-yes}
DO_UDP=${DO_UDP:-yes}
DO_TCP=${DO_TCP:-yes}
INTERFACE=${INTERFACE:-0.0.0.0}
SO_REUSEPORT=${SO_REUSEPORT:-no}
HIDE_IDENTITY=${HIDE_IDENTITY:-no}
HIDE_VERSION=${HIDE_VERSION:-no}
VERBOSITY=${VERBOSITY:-0}
NUM_THREADS=${NUM_THREADS:-1}
QNAME_MINIMISATION=${QNAME_MINIMISATION:-yes}
RRSET_ROUNDROBIN=${RRSET_ROUNDROBIN:-yes}
USE_CAPS_FOR_ID=${USE_CAPS_FOR_ID:-yes}
USE_LOGFILE=${ENABLE_LOGFILE:-no}
USE_CHROOT=${ENABLE_CHROOT:-yes}
ENABLE_REMOTE_CONTROL=${ENABLE_REMOTE_CONTROL:-no}
DISABLE_CONF_VARS=${DISABLE_CONF_VARS:-no}
UPDATE_TRUST_ANCHOR=${UPDATE_TRUST_ANCHOR:-yes}

if [ "x${DISABLE_CONF_VARS}" = "xno" ]; then
  sed 's/{{PORT}}/'"${PORT}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{DO_IPV6}}/'"${DO_IPV6}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{DO_IPV4}}/'"${DO_IPV4}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{DO_UDP}}/'"${DO_UDP}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{DO_TCP}}/'"${DO_TCP}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{INTERFACE}}/'"${INTERFACE}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{SO_REUSEPORT}}/'"${SO_REUSEPORT}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{HIDE_IDENTITY}}/'"${HIDE_IDENTITY}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{HIDE_VERSION}}/'"${HIDE_VERSION}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{VERBOSITY}}/'"${VERBOSITY}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{NUM_THREADS}}/'"${NUM_THREADS}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{QNAME_MINIMISATION}}/'"${QNAME_MINIMISATION}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{RRSET_ROUNDROBIN}}/'"${RRSET_ROUNDROBIN}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{USE_CAPS_FOR_ID}}/'"${USE_CAPS_FOR_ID}"'/' -i /opt/unbound/etc/unbound/unbound.conf
  sed 's/{{ENABLE_REMOTE_CONTROL}}/'"${ENABLE_REMOTE_CONTROL}"'/' -i /opt/unbound/etc/unbound/unbound.conf

  if [ "x${ENABLE_REMOTE_CONTROL}" = "xyes" ]; then
    if [ ! -f /opt/unbound/etc/unbound/unbound_control.key ]; then
      /opt/unbound/sbin/unbound-control-setup 1>/dev/null 2>&1 || true
    fi
  fi

  if [ "x${USE_LOGFILE}" = "xyes" ]; then
    mkdir -p /opt/unbound/etc/unbound/log && \
       chown unbound.unbound /opt/unbound/etc/unbound/log
    sed 's/{{LOGFILE}}/log\/unbound.log/' -i /opt/unbound/etc/unbound/unbound.conf
  else
    sed 's/{{LOGFILE}}//' -i /opt/unbound/etc/unbound/unbound.conf
  fi
fi

if [ "x${USE_CHROOT}" = "xno" ]; then
  if ! grep -q "chroot:" /opt/unbound/etc/unbound/unbound.conf; then
    echo "    chroot: \"\"" >> /opt/unbound/etc/unbound/unbound.conf
  fi
else
  mkdir -p /opt/unbound/etc/unbound/dev
  cp -a /dev/random /dev/urandom /opt/unbound/etc/unbound/dev/
  chown unbound.unbound /opt/unbound/etc/unbound
fi

if [ "x${UPDATE_TRUST_ANCHOR}" = "xyes" ]; then
  echo "Update root trust anchor for DNSSEC validation."
  /opt/unbound/sbin/unbound-anchor -a /opt/unbound/etc/unbound/root.key
  chown unbound.unbound /opt/unbound/etc/unbound/root.key
fi

cat /opt/unbound/etc/unbound/unbound.conf
echo "-----------------------------------------------"

exec /opt/unbound/sbin/unbound -d -c /opt/unbound/etc/unbound/unbound.conf
