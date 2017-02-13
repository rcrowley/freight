if tty -s; then
  TTY="1"
fi

# Fetch the given field from the package's control file.
apt_info() {
    egrep -i "^$2:" "$1" | cut -d: -f2- | awk '{print $1}'
}

# Print the package name from the given control file.
apt_binary_name() {
    apt_info "$1" Package
}

# Print the version from the given control file.
apt_binary_version() {
    apt_info "$1" Version
}

# Print the architecture from the given control file.
apt_binary_arch() {
    apt_info "$1" Architecture
}

apt_binary_filesize() {
    apt_info "$1" Size
}

# Print the source name from the given control file.
apt_binary_sourcename() {
    SOURCE="$(apt_info "$1" Source)"
    [ -z "$SOURCE" ] && SOURCE="$(apt_binary_name "$1")"
    echo "$SOURCE"
}

# Print the prefix the given control file should use in the pool.
apt_binary_prefix() {
    apt_prefix "$(apt_binary_sourcename "$1")"
}

# Print the name portion of a source package's pathname.
apt_source_name() {
    basename "$1" ".dsc" | cut -d_ -f1
}

# Print the version portion of a source package's pathname.
apt_source_version() {
    basename "$1" ".dsc" | cut -d_ -f2
}

# Print the original version portion of a source package's pathname.
apt_source_origversion() {
    apt_source_version "$1" | cut -d- -f1
}

# Print the prefix for a package name.
apt_prefix() {
    [ "$(echo "$1" | cut -c1-3)" = "lib" ] && C=4 || C=1
    echo "$1" | cut -c-$C
}

# Print the checksum portion of the normal checksumming programs' output.
apt_md5() {
    md5sum "$1" | cut -d" " -f1
}
apt_sha1() {
    sha1sum "$1" | cut -d" " -f1
}
apt_sha256() {
    sha256sum "$1" | cut -d" " -f1
}
apt_sha512() {
    sha512sum "$1" | cut -d" " -f1
}

# Print the size of the given file.
apt_filesize() {
    stat -c%s "$1"
}

# Setup the repository for the distro named in the first argument,
# including all packages read from `stdin`.
apt_cache() {
    REL_DATE="$(LC_ALL=en_US date -u '+%a, %d %b %Y %H:%M:%S %Z')"
    VALID_DATE="Tue, 30 Nov 2038 00:00:00 UTC"
    DIST="$1"
    SUITE="${SUITE:-$DIST}"

    # Generate a timestamp to use in this build's directory name.
    DATE="$(date +%Y%m%d%H%M%S%N)"
    DISTCACHE="$VARCACHE/dists/$DIST-$DATE"

    # For a Debian archive, each distribution needs at least this directory
    # structure in place.  The directory for this build must not exist,
    # otherwise this build would clobber a previous one.  The `.refs`
    # directory contains links to all the packages currently included in
    # this distribution to enable cleaning by link count later.
    mkdir -p "$DISTCACHE/.refs"
    mkdir -p "$VARCACHE/pool/$DIST"

    # Work through every package that should be part of this distro.
    while read PATHNAME
    do

        # Extract the component, if present, from the package's pathname.
        case "$PATHNAME" in
            */*) COMP="${PATHNAME%%/*}" PACKAGE="${PATHNAME##*/}";;
            *) COMP="main" PACKAGE="$PATHNAME";;
        esac

        case "$PATHNAME" in

            # Binary packages.
            *.deb) apt_cache_binary "$DIST" "$DISTCACHE" "$PATHNAME" "$COMP" "$PACKAGE";;

            # Source packages.  The *.dsc file is considered the "entrypoint"
            # and will find the associated *.orig.tar.gz, *.diff.gz, and/or
            # *.tar.gz as they are needed.
            *.dsc) apt_cache_source "$DIST" "$DISTCACHE" "$PATHNAME" "$COMP" "$PACKAGE";;
            *.debian.tar.gz|*.debian.tar.bz2|*.debian.tar.xz|*.debian.tar.lzma|*.diff.gz|*.orig.tar.gz|*.orig.tar.bz2|*.orig.tar.xz|*.orig.tar.lzma|*.tar.gz|*.tar.bz2|*.tar.xz|*.tar.lzma|*.deb-control|*.dsc-cached) ;;

            *) echo "# [freight] skipping extraneous file $PATHNAME" >&2;;
        esac
    done
    COMPS="$(ls "$DISTCACHE")"

    # Build a `Release` file for each component and architecture.  `gzip`
    # the `Packages` file, too.
    for COMP in $COMPS
    do
        # shellcheck disable=SC2153
        for ARCH in $ARCHS
        do
            if [ -d "$DISTCACHE/$COMP/binary-$ARCH" ]
            then
                cat >"$DISTCACHE/$COMP/binary-$ARCH/Release" <<EOF
Archive: $SUITE
Component: $COMP
Origin: $ORIGIN
Label: $LABEL
Architecture: $ARCH
Date: $REL_DATE
Valid-Until: $VALID_DATE
EOF
                gzip -c "$DISTCACHE/$COMP/binary-$ARCH/Packages" \
                    >"$DISTCACHE/$COMP/binary-$ARCH/Packages.gz"
            fi
        done
        if [ -d "$DISTCACHE/$COMP/source" ]
        then
            cat >"$DISTCACHE/$COMP/source/Release" <<EOF
Archive: $SUITE
Component: $COMP
Origin: $ORIGIN
Label: $LABEL
Architecture: source
Date: $REL_DATE
Valid-Until: $VALID_DATE
EOF
            gzip -c "$DISTCACHE/$COMP/source/Sources" \
                >"$DISTCACHE/$COMP/source/Sources.gz"
        fi
    done

    # Begin the top-level `Release` file with the lists of components
    # and architectures present in this repository and the checksums
    # of all the `Release` and `Packages.gz` files within.
    {
        cat <<EOF
Origin: $ORIGIN
Label: $LABEL
Suite: $SUITE
Codename: $DIST
Components: $(echo "$COMPS" | tr \\n " ")
Architectures: $ARCHS
Date: $REL_DATE
Valid-Until: $VALID_DATE
EOF

        # Finish the top-level `Release` file with references and
        # checksums for each sub-`Release` file and `Packages.gz` file.
        # In the future, `Sources` may find a place here, too.
        find "$DISTCACHE" -mindepth 2 -type f -printf %P\\n |
        grep -v ^\\. |
        while read FILE
        do
            SIZE="$(apt_filesize "$DISTCACHE/$FILE")"
            echo " $(apt_md5 "$DISTCACHE/$FILE" ) $SIZE $FILE" >&3
            echo " $(apt_sha1 "$DISTCACHE/$FILE" ) $SIZE $FILE" >&4
            echo " $(apt_sha256 "$DISTCACHE/$FILE" ) $SIZE $FILE" >&5
            echo " $(apt_sha512 "$DISTCACHE/$FILE" ) $SIZE $FILE" >&6
        done 3>"$TMP/md5sums" 4>"$TMP/sha1sums" 5>"$TMP/sha256sums" 6>"$TMP/sha512sums"
        echo "MD5Sum:"
        cat "$TMP/md5sums"
        echo "SHA1:"
        cat "$TMP/sha1sums"
        echo "SHA256:"
        cat "$TMP/sha256sums"
        echo "SHA512:"
        cat "$TMP/sha512sums"

    } >"$DISTCACHE/Release"

    # Sign the top-level `Release` file with `gpg`, for each key and
    # concatenate signatures.
    for GPGKEY in $GPG; do
        # shellcheck disable=SC2046
        gpg -abs$([ "$TTY" ] || echo " --no-tty") --use-agent -u"$GPGKEY" \
            $([ "$GPG_PASSPHRASE_FILE" ] && echo " --batch --passphrase-fd 1 --passphrase-file $GPG_PASSPHRASE_FILE") \
            $([ "$GPG_DIGEST_ALGO" ] && echo " --personal-digest-preferences $GPG_DIGEST_ALGO") \
            -o"$TMP/release_last_signature.gpg" "$DISTCACHE/Release" || {
            cat <<EOF
# [freight] couldn't sign the repository, perhaps you need to run
# [freight] gpg --gen-key and update the GPG setting in $CONF
# [freight] (see freight(5) for more information)
EOF
            rm -rf "$DISTCACHE"
            exit 1
        }
        cat "$TMP"/release_last_signature.gpg >> "$DISTCACHE"/Release.gpg
        rm -f "$TMP"/release_last_signature.gpg
    done

    # Generate `pubkey.gpg` containing the plaintext public key and
    # `keyring.gpg` containing a complete GPG keyring containing only
    # the appropriate public keys.  `keyring.gpg` is appropriate for
    # copying directly to `/etc/apt/trusted.gpg.d`.
    mkdir -m700 -p "$TMP/gpg"
    # Create `pubring.gpg` to prevent gpg version >= 2.1 from using the
    # new `pubring.kbx` format during an initial `gpg --import`.
    : > "$TMP/gpg/pubring.gpg" && chmod 644 "$TMP/gpg/pubring.gpg"
    # shellcheck disable=SC2086
    gpg -q --export -a $GPG |
    tee "$VARCACHE/pubkey.gpg" |
    gpg -q --homedir "$TMP/gpg" --import
    mv "$TMP/gpg/pubring.gpg" "$VARCACHE/keyring.gpg"

    # Move the symbolic link for this distro to this build.
    ln -s "$DIST-$DATE" "$DISTCACHE-"
    OLD="$(readlink "$VARCACHE/dists/$DIST" || true)"
    mv -T "$DISTCACHE-" "$VARCACHE/dists/$DIST"
    [ -z "$OLD" ] || rm -rf "$VARCACHE/dists/$OLD"

}

# Clear the cached control files from the dist
apt_clear_cache() {
    # First remove the binary control cache
    find "$VARLIB/apt/$DIST" -name '*-control' -print0 | xargs -0 --no-run-if-empty rm
    # Next remove the source control cache
    find "$VARLIB/apt/$DIST" -name '*-cached' -print0 | xargs -0 --no-run-if-empty rm
}

# Add a binary package to the given dist and to the pool.
apt_cache_binary() {
    DIST="$1"
    DISTCACHE="$2"
    PATHNAME="$3"
    COMP="$4"
    PACKAGE="$5"

    # Verify this package by way of extracting its control information
    # to be used throughout this iteration of the loop.
    # Don't extract the deb archive each time. Stick the control file
    # in the $VARLIB alongside the other package artifacts for easy
    # use later.
    if [ "$CACHE" = "on" ]; then
        CONTROL="$VARLIB/apt/$DIST/$PATHNAME-control"
    else
        CONTROL="$TMP/DEBIAN/binary-control"
    fi
    # If caching is off or if the binary has changed size, this will generate the
    # binary control file
    if ! ( [ -e "$CONTROL" ] && \
        [ "$(apt_binary_filesize "$CONTROL")" -eq "$(apt_filesize "$VARLIB/apt/$DIST/$PATHNAME")" ] ); then
        dpkg-deb -e "$VARLIB/apt/$DIST/$PATHNAME" "$TMP/DEBIAN" || {
            echo "# [freight] skipping invalid Debian package $PATHNAME" >&2
            return
        }
        {
            # Grab and augment the control file from this package.  Remove
            # `Size`, `MD5Sum`, etc. lines and replace them with newly
            # generated values. Update it once when generating the
            # cached control file. Add a Filename line that can be updated
            # easily later with the real path.  Strip out empty control fields
            # as these might cause problems.
            grep . "$TMP/DEBIAN/control" |
            grep -E -v "^[A-Za-z-]+:\s+$" |
            grep -v "^(Essential|Filename|MD5Sum|SHA1|SHA256|SHA512|Size)"
            cat <<EOF
Filename: FILENAME
MD5sum: $(apt_md5 "$VARLIB/apt/$DIST/$PATHNAME")
SHA1: $(apt_sha1 "$VARLIB/apt/$DIST/$PATHNAME")
SHA256: $(apt_sha256 "$VARLIB/apt/$DIST/$PATHNAME")
SHA512: $(apt_sha512 "$VARLIB/apt/$DIST/$PATHNAME")
Size: $(apt_filesize "$VARLIB/apt/$DIST/$PATHNAME")
EOF
        echo
        } > "$CONTROL"
    fi

    # Create all architecture-specific directories.  This will allow
    # packages marked `all` to actually be placed in all architectures.
    for ARCH in $ARCHS
    do
        mkdir -p "$DISTCACHE/$COMP/binary-$ARCH"
        touch "$DISTCACHE/$COMP/binary-$ARCH/Packages"
    done

    # Link or copy this package into this distro's `.refs` directory.
    mkdir -p "$DISTCACHE/.refs/$COMP"
    ln "$VARLIB/apt/$DIST/$PATHNAME" "$DISTCACHE/.refs/$COMP" ||
    cp "$VARLIB/apt/$DIST/$PATHNAME" "$DISTCACHE/.refs/$COMP"

    # Package properties.  Remove the epoch from the version number
    # in the package filename, as is customary.
    ARCH="$(apt_binary_arch "$CONTROL")"
    NAME="$(apt_binary_name "$CONTROL")"
    VERSION="$(apt_binary_version "$CONTROL")"
    PREFIX="$(apt_binary_prefix "$CONTROL")"
    SOURCE="$(apt_binary_sourcename "$CONTROL")"
    FILENAME="${NAME}_${VERSION##*:}_${ARCH}.deb"

    # Link this package into the pool.
    POOL="pool/$DIST/$COMP/$PREFIX/$SOURCE"
    mkdir -p "$VARCACHE/$POOL"
    if [ ! -f "$VARCACHE/$POOL/$FILENAME" ]
    then
        if [ "$PACKAGE" != "$FILENAME" ]
        then echo "# [freight] adding $PACKAGE to pool (as $FILENAME)" >&2
        else echo "# [freight] adding $PACKAGE to pool" >&2
        fi
        ln "$DISTCACHE/.refs/$COMP/$PACKAGE" "$VARCACHE/$POOL/$FILENAME"
    fi

    # Build a list of the one-or-more `Packages` files to append with
    # this package's info.
    if [ "$ARCH" = "all" ]
    then FILES="$(find "$DISTCACHE/$COMP" -type f -name "Packages")"
    else FILES="$DISTCACHE/$COMP/binary-$ARCH/Packages"
    fi

    # Add the `Filename` field containing the path to the
    # package, starting with `pool/`.
    # shellcheck disable=SC2086
    sed "s,^Filename: FILENAME$,Filename: $POOL/$FILENAME,g" "$CONTROL" |
    tee -a $FILES >/dev/null

    # Cleanup the extracted package
    if [ -d "$TMP/DEBIAN" ]; then
        rm -rf "$TMP/DEBIAN"
    fi

}

# Add a source package to the given dist and to the pool.  *.orig.tar.gz,
# *.diff.gz, and/or *.tar.gz will be found based on PATHNAME and associated
# with the correct source package.
apt_cache_source() {
    DIST="$1"
    DISTCACHE="$2"
    PATHNAME="$3"
    COMP="$4"
    PACKAGE="$5"

    NAME="$(apt_source_name "$PATHNAME")"
    VERSION="$(apt_source_version "$PATHNAME")"
    ORIG_VERSION="$(apt_source_origversion "$PATHNAME")"
    DIRNAME="$(dirname "$PATHNAME")"
    DSC_FILENAME="${NAME}_${VERSION%*:}.dsc"
    DEBTAR_GZ_FILENAME="${NAME}_${VERSION%*:}.debian.tar.gz"
    DEBTAR_BZ2_FILENAME="${NAME}_${VERSION%*:}.debian.tar.bz2"
    DEBTAR_XZ_FILENAME="${NAME}_${VERSION%*:}.debian.tar.xz"
    DEBTAR_LZMA_FILENAME="${NAME}_${VERSION%*:}.debian.tar.lzma"
    DIFFGZ_FILENAME="${NAME}_${VERSION%*:}.diff.gz"
    ORIG_FILENAME="${NAME}_${ORIG_VERSION}.orig.tar.gz"
    TAR_FILENAME="${NAME}_${VERSION%*:}.tar.gz"

    # Find which style of diff they're using.
    if [ -f "$VARLIB/apt/$DIST/$DIRNAME/$DEBTAR_GZ_FILENAME" ]
    then DIFF_FILENAME=${DEBTAR_GZ_FILENAME}
    elif [ -f "$VARLIB/apt/$DIST/$DIRNAME/$DEBTAR_BZ2_FILENAME" ]
    then DIFF_FILENAME=${DEBTAR_BZ2_FILENAME}
    elif [ -f "$VARLIB/apt/$DIST/$DIRNAME/$DEBTAR_XZ_FILENAME" ]
    then DIFF_FILENAME=${DEBTAR_XZ_FILENAME}
    elif [ -f "$VARLIB/apt/$DIST/$DIRNAME/$DEBTAR_LZMA_FILENAME" ]
    then DIFF_FILENAME=${DEBTAR_LZMA_FILENAME}
    else DIFF_FILENAME=${DIFFGZ_FILENAME}
    fi

    # Verify this package by ensuring the other necessary files are present.
    [ -f "$VARLIB/apt/$DIST/$DIRNAME/$ORIG_FILENAME" -a -f "$VARLIB/apt/$DIST/$DIRNAME/$DIFF_FILENAME" -o -f "$VARLIB/apt/$DIST/$DIRNAME/$TAR_FILENAME" ] || {
        echo "# [freight] skipping invalid Debian source package $PATHNAME" >&2
        return
    }

    # Create the architecture-parallel source directory and manifest.
    mkdir -p "$DISTCACHE/$COMP/source"
    touch "$DISTCACHE/$COMP/source/Sources"

    # Link or copy this source package into this distro's `.refs` directory
    # if it isn't already there (which can happen when two packages derive
    # from the same original tarball).
    mkdir -p "$DISTCACHE/.refs/$COMP"
    for FILENAME in "$DSC_FILENAME" "$ORIG_FILENAME" "$DIFF_FILENAME" "$TAR_FILENAME"
    do
        [ -f "$VARLIB/apt/$DIST/$DIRNAME/$FILENAME" ] || continue
        [ -f "$DISTCACHE/.refs/$COMP/$FILENAME" ] ||
        ln "$VARLIB/apt/$DIST/$DIRNAME/$FILENAME" "$DISTCACHE/.refs/$COMP" ||
        cp "$VARLIB/apt/$DIST/$DIRNAME/$FILENAME" "$DISTCACHE/.refs/$COMP"
    done

    # Package properties.  Remove the epoch from the version number
    # in the package filename, as is customary.

    # Link this source package into the pool.
    POOL="pool/$DIST/$COMP/$(apt_prefix "$NAME")/$NAME"
    mkdir -p "$VARCACHE/$POOL"
    for FILENAME in "$DSC_FILENAME" "$ORIG_FILENAME" "$DIFF_FILENAME" "$TAR_FILENAME"
    do
        if [ -f "$DISTCACHE/.refs/$COMP/$FILENAME" -a ! -f "$VARCACHE/$POOL/$FILENAME" ]
        then
            echo "# [freight] adding $FILENAME to pool" >&2
            ln "$DISTCACHE/.refs/$COMP/$FILENAME" "$VARCACHE/$POOL"
        fi
    done

    # Grab and augment the control fields from this source package.  Remove
    # and recalculate file checksums.  Change the `Source` field to `Package`.
    # Add the `Directory` field. Only do this if a cached copy does not exist.
    if [ "$CACHE" = "on" ]; then
        CONTROL="$VARLIB/apt/$DIST/$PATHNAME-cached"
    else
        CONTROL="$TMP/source-control"
    fi
    if ! [ -e "$CONTROL" ]; then
        {
            egrep "^[A-Z][^:]+: ." "$VARLIB/apt/$DIST/$PATHNAME" |
            egrep -v "^(Version: GnuPG|Hash: )" |
            sed "s/^Source:/Package:/"
            echo "Directory: DIRECTORY"
            echo "Files:"
            for FILENAME in "$DSC_FILENAME" "$ORIG_FILENAME" "$DIFF_FILENAME" "$TAR_FILENAME"
            do
                [ -f "$VARCACHE/$POOL/$FILENAME" ] || continue
                SIZE="$(apt_filesize "$VARCACHE/$POOL/$FILENAME")"
                MD5="$(apt_md5 "$VARCACHE/$POOL/$FILENAME")"
                echo " $MD5 $SIZE $FILENAME"
            done
            echo "Checksums-Sha1:"
            for FILENAME in "$DSC_FILENAME" "$ORIG_FILENAME" "$DIFF_FILENAME" "$TAR_FILENAME"
            do
                [ -f "$VARCACHE/$POOL/$FILENAME" ] || continue
                SIZE="$(apt_filesize "$VARCACHE/$POOL/$FILENAME")"
                SHA1="$(apt_sha1 "$VARCACHE/$POOL/$FILENAME")"
                echo " $SHA1 $SIZE $FILENAME"
            done
            echo "Checksums-Sha256:"
            for FILENAME in "$DSC_FILENAME" "$ORIG_FILENAME" "$DIFF_FILENAME" "$TAR_FILENAME"
            do
                [ -f "$VARCACHE/$POOL/$FILENAME" ] || continue
                SIZE="$(apt_filesize "$VARCACHE/$POOL/$FILENAME")"
                SHA256="$(apt_sha256 "$VARCACHE/$POOL/$FILENAME")"
                echo " $SHA256 $SIZE $FILENAME"
            done
            echo "Checksums-Sha512:"
            for FILENAME in "$DSC_FILENAME" "$ORIG_FILENAME" "$DIFF_FILENAME" "$TAR_FILENAME"
            do
                [ -f "$VARCACHE/$POOL/$FILENAME" ] || continue
                SIZE="$(apt_filesize "$VARCACHE/$POOL/$FILENAME")"
                SHA512="$(apt_sha512 "$VARCACHE/$POOL/$FILENAME")"
                echo " $SHA512 $SIZE $FILENAME"
            done
            echo
        } > "$CONTROL"
    fi

    sed "s,^Directory: DIRECTORY$,Directory: $POOL,g" "$CONTROL" |
    tee -a "$DISTCACHE/$COMP/source/Sources" >/dev/null

# Clean up the tmp space
    if [ -f "$TMP/source-control" ]; then
        rm "$TMP/source-control"
    fi

}

# Clean up old packages in the pool.
apt_clean() {
    find "$VARCACHE/pool" -links 1 -type f -delete
    find "$VARCACHE/pool" -type d -empty -delete
}

# vim: et:ts=4:sw=4
