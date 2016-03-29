# vim: et:ts=4:sw=4:ft=sh

load freight_helpers
load apt_helpers

setup() {
    freight_init
    freight_add ${FIXTURES}/test_1.0_all.deb apt/example
    freight_add ${FIXTURES}/test_1.0_all.deb apt/example/comp
    configure_local_apt
}

@test "freight-cache builds distro Release file" {
    freight_cache -v
    test -e ${FREIGHT_CACHE}/dists/example/Release
    egrep "^Components: comp main" ${FREIGHT_CACHE}/dists/example/Release
}

@test "freight-cache builds per-component Release file" {
    freight_cache -v
    test -e ${FREIGHT_CACHE}/dists/example/comp/binary-amd64/Release
    test -e ${FREIGHT_CACHE}/dists/example/main/binary-amd64/Release
}

@test "freight-cache builds pool" {
    freight_cache -v
    test -e ${FREIGHT_CACHE}/pool/example/comp/t/test/test_1.0_all.deb
    test -e ${FREIGHT_CACHE}/pool/example/main/t/test/test_1.0_all.deb
}

@test "freight-cache generates valid Release.gpg signature" {
    freight_cache -v
    gpg --verify ${FREIGHT_CACHE}/dists/example/Release.gpg ${FREIGHT_CACHE}/dists/example/Release
}

@test "freight-cache signs Release.gpg with two keys" {
    sed -i 's/^GPG=.*/GPG="freight@example.com freight2@example.com"/' $FREIGHT_CONFIG
    freight_cache -v
    test $(grep -c BEGIN ${FREIGHT_CACHE}/dists/example/Release.gpg) -eq 2
    gpg --verify ${FREIGHT_CACHE}/dists/example/Release.gpg ${FREIGHT_CACHE}/dists/example/Release
}

@test "freight-cache works without tty" {
    run freight_cache_nohup -v
    assert_success
}

@test "apt-get fetches package list" {
    check_apt_support
    freight_cache -v
    echo "deb file://${FREIGHT_CACHE} example main" > ${TMPDIR}/apt/etc/apt/sources.list
    apt-get -c ${FIXTURES}/apt.conf update
    apt-cache -c ${FIXTURES}/apt.conf show test
}

@test "freight-cache removes deleted packages from pool" {
    freight_cache -v
    test -e ${FREIGHT_CACHE}/pool/example/main/t/test/test_1.0_all.deb
    rm -f ${FREIGHT_LIB}/apt/example/test_1.0_all.deb

    run freight_cache -v
    assert_success
    assert_output ""
    test ! -e ${FREIGHT_CACHE}/pool/example/main/t/test/test_1.0_all.deb
}

@test "freight-cache --keep retains deleted packages in pool" {
    freight_cache -v
    test -e ${FREIGHT_CACHE}/pool/example/main/t/test/test_1.0_all.deb
    rm -f ${FREIGHT_LIB}/apt/example/test_1.0_all.deb

    run freight_cache -v --keep
    assert_success
    assert_output ""
    test -e ${FREIGHT_CACHE}/pool/example/main/t/test/test_1.0_all.deb
}

@test "freight-cache handles VARLIB being a symlink" {
    mv $FREIGHT_LIB ${FREIGHT_LIB}_real
    ln -s ${FREIGHT_LIB}_real $FREIGHT_LIB
    freight_cache
    test -e ${FREIGHT_CACHE}/pool/example/comp/t/test/test_1.0_all.deb
    test -e ${FREIGHT_CACHE}/pool/example/main/t/test/test_1.0_all.deb
}
