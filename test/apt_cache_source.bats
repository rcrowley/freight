# vim: et:ts=4:sw=4:ft=sh

load freight_helpers
load apt_helpers

setup() {
    freight_init
    configure_local_apt
}

@test "freight-cache skips partial source packages" {
    freight_add ${FIXTURES}/source_1.0-1.dsc apt/example
    run freight_cache
    assert_success
    assert_output "# [freight] skipping invalid Debian source package source_1.0-1.dsc"
}

@test "freight-cache builds source-only archive" {
    freight_add ${FIXTURES}/source_1.0-1.dsc apt/example
    freight_add ${FIXTURES}/source_1.0-1.tar.gz apt/example
    freight_add ${FIXTURES}/source_1.0.orig.tar.gz apt/example
    run freight_cache
    assert_success
    echo -e "# [freight] adding source_1.0-1.dsc to pool\n# [freight] adding source_1.0.orig.tar.gz to pool\n# [freight] adding source_1.0-1.tar.gz to pool" | assert_output
    test -e ${FREIGHT_CACHE}/pool/example/main/s/source/source_1.0-1.dsc
    test -e ${FREIGHT_CACHE}/pool/example/main/s/source/source_1.0-1.tar.gz
    test -e ${FREIGHT_CACHE}/pool/example/main/s/source/source_1.0.orig.tar.gz
}

@test "apt-get fetches source package list" {
    check_apt_support
    freight_add ${FIXTURES}/source_1.0-1.dsc apt/example
    freight_add ${FIXTURES}/source_1.0-1.tar.gz apt/example
    freight_add ${FIXTURES}/source_1.0.orig.tar.gz apt/example
    freight_cache

    echo "deb-src file://${FREIGHT_CACHE} example main" > ${TMPDIR}/apt/etc/apt/sources.list
    apt-get -c ${FIXTURES}/apt.conf update
    apt-cache -c ${FIXTURES}/apt.conf showsrc source | grep "Package: source"
}
