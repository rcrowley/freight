# vim: et:ts=4:sw=4:ft=sh

configure_local_apt() {
    mkdir -p ${TMPDIR}/apt/etc/apt
    mkdir -p ${TMPDIR}/apt/var/lib/apt
    mkdir -p ${TMPDIR}/apt/var/cache/apt
}

check_apt_support() {
    type apt-get || skip "missing apt-get"
    apt-get --version | grep Ver:.*deb || skip "missing apt-get deb support"
}
