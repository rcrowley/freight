# vim: et:ts=4:sw=4:ft=sh

TOPDIR=$PWD
FIXTURES=${TOPDIR}/test/fixtures
TMPDIR=${TOPDIR}/test/tmp

load ${TMPDIR}/bats-assert/all.bash

FREIGHT_HOME=${TMPDIR}/freight
FREIGHT_CONFIG=${FREIGHT_HOME}/etc/freight.conf
FREIGHT_CACHE=${FREIGHT_HOME}/var/cache
FREIGHT_LIB=${FREIGHT_HOME}/var/lib

export GNUPGHOME=${TMPDIR}/gpg

freight_init() {
    gpg_init
    rm -rf $FREIGHT_HOME
    mkdir -p $FREIGHT_CACHE $FREIGHT_LIB
    bin/freight init \
        -g freight@example.com \
        -c $FREIGHT_CONFIG \
        --libdir $FREIGHT_LIB \
        --cachedir $FREIGHT_CACHE \
        "$@"
}

freight_add() {
    bin/freight add -c $FREIGHT_CONFIG "$@"
}

freight_cache() {
    bin/freight cache -c $FREIGHT_CONFIG "$@"
}

freight_cache_nohup() {
    nohup bin/freight cache -c $FREIGHT_CONFIG "$@"
}

# Generates a GPG key for all tests, once only due to entropy required
gpg_init() {
    if [ ! -e $GNUPGHOME ]; then
        mkdir -p $GNUPGHOME
        chmod 0700 $GNUPGHOME
        gpg --batch --gen-key test/fixtures/gpg.conf
        gpg --batch --gen-key test/fixtures/gpg2.conf
    fi
}
