# Print the package name from the given package filename.
apt_name() {
	basename "$1" .deb | cut -d_ -f1
}

# Print the version from the given package filename.
apt_version() {
	basename "$1" .deb | cut -d_ -f2
}

# Print the architecture from the given package filename.
apt_arch() {
	basename "$1" .deb | cut -d_ -f3
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

# Print the size of the given file.
apt_filesize() {
	stat -c%s "$1"
}

# Setup the repository for the distro named in the first argument,
# including all packages read from `stdin`.
apt_cache() {
	DIST="$1"

	# Generate a timestamp to use in this build's directory name.
	DATE="$(date +%Y%m%d%H%M%S%N)"

	# For a Debian archive, each distribution needs at least this directory
	# structure in place.  The directory for this build must not exist,
	# otherwise this build would clobber a previous one.  The `.refs`
	# directory contains links to all the packages currently included in
	# this distribution to enable cleaning by link count later.
	mkdir -p "$VARCACHE/dists/$DIST-$DATE/.refs"
	mkdir -p "$VARCACHE/pool/$DIST"

	# Work through every package that should be part of this distro.
	while read PATHNAME
	do
		case "$PATHNAME" in
			*/*) COMP="${PATHNAME%%/*}" PACKAGE="${PATHNAME##*/}";;
			*) COMP="main" PACKAGE="$PATHNAME";;
		esac

		# Create all architecture-specific directories.  This will allow
		# packages marked `all` to actually be placed in all architectures.
		for ARCH in $ARCHS
		do
			mkdir -p "$VARCACHE/dists/$DIST-$DATE/$COMP/binary-$ARCH"
			touch "$VARCACHE/dists/$DIST-$DATE/$COMP/binary-$ARCH/Packages"
		done

		# Link or copy this package into this distro's `.refs` directory.
		REFS="$VARCACHE/dists/$DIST-$DATE/.refs/$COMP"
		mkdir -p "$REFS"
		ln "$VARLIB/apt/$DIST/$PATHNAME" "$REFS" ||
		cp "$VARLIB/apt/$DIST/$PATHNAME" "$REFS"

		# Link this package into the pool.
		[ "$(echo "$PACKAGE" | cut -c1-3)" = "lib" ] && C=4 || C=1
		POOL="pool/$DIST/$COMP/$(echo "$PACKAGE" |
			cut -c-$C)/$(apt_name "$PACKAGE")"
		mkdir -p "$VARCACHE/$POOL"
		if [ -f "$VARCACHE/$POOL/$PACKAGE" ]
		then
			echo "# [freight] pool already has $PACKAGE" >&2
		else
			ln "$REFS/$PACKAGE" "$VARCACHE/$POOL/$PACKAGE"
		fi

		# Build a list of the one-or-more `Packages` files to append with
		# this package's info.
		ARCH="$(apt_arch "$PACKAGE")"
		if [ "$ARCH" = "all" ]
		then
			FILES="$(find "$VARCACHE/dists/$DIST-$DATE/$COMP" -type f)"
		else
			FILES="$VARCACHE/dists/$DIST-$DATE/$COMP/binary-$ARCH/Packages"
		fi

		# Grab and augment the control file from this package.  Remove
		# `Size`, `MD5Sum`, etc. lines and replace them with newly
		# generated values.  Add the `Filename` field containing the
		# path to the package, starting with `pool/`.
		dpkg-deb -e "$VARLIB/apt/$DIST/$PATHNAME" "$TMP/DEBIAN"
		{
			grep . "$TMP/DEBIAN/control" \
				| grep -v "^(Essential|Filename|MD5Sum|SHA1|SHA256|Size)"
			cat <<EOF
Filename: $POOL/$PACKAGE
MD5Sum: $(apt_md5 "$VARLIB/apt/$DIST/$PATHNAME")
SHA1: $(apt_sha1 "$VARLIB/apt/$DIST/$PATHNAME")
SHA256: $(apt_sha256 "$VARLIB/apt/$DIST/$PATHNAME")
Size: $(apt_filesize "$VARLIB/apt/$DIST/$PATHNAME")
EOF
			echo
		} | tee -a $FILES >/dev/null
		rm -rf "$TMP/DEBIAN"

	done
	COMPS="$(find "$VARCACHE/dists/$DIST-$DATE" -mindepth 1 -maxdepth 1 \
		-type d ! -name .refs -printf "%P ")"

	# Build a `Release` file for each component and architecture.  `gzip`
	# the `Packages` file, too.
	for COMP in $COMPS
	do
		for ARCH in $ARCHS
		do
			cat >"$VARCACHE/dists/$DIST-$DATE/$COMP/binary-$ARCH/Release" <<EOF
Archive: $DIST
Component: $COMP
Origin: $ORIGIN
Label: $LABEL
Architecture: $ARCH
EOF
			gzip -c "$VARCACHE/dists/$DIST-$DATE/$COMP/binary-$ARCH/Packages" \
				>"$VARCACHE/dists/$DIST-$DATE/$COMP/binary-$ARCH/Packages.gz"
		done
	done

	# Begin the top-level `Release` file with the lists of components
	# and architectures present in this repository and the checksums
	# of all the `Release` and `Packages.gz` files within.
	{
		cat <<EOF
Origin: $ORIGIN
Label: $LABEL
Codename: $DIST
Components: ${COMPS% }
Architectures: $ARCHS
EOF

		# Finish the top-level `Release` file with references and
		# checksums for each sub-`Release` file and `Packages.gz` file.
		# In the future, `Sources` may find a place here, too.
		find "$VARCACHE/dists/$DIST-$DATE" -mindepth 2 -type f -printf %P\\n |
		grep -v ^\\. |
		while read FILE
		do
			SIZE="$(apt_filesize "$VARCACHE/dists/$DIST-$DATE/$FILE")"
			echo " $(apt_md5 "$VARCACHE/dists/$DIST-$DATE/$FILE" \
				) $SIZE $FILE" >&3
			echo " $(apt_sha1 "$VARCACHE/dists/$DIST-$DATE/$FILE" \
				) $SIZE $FILE" >&4
			echo " $(apt_sha256 "$VARCACHE/dists/$DIST-$DATE/$FILE" \
				) $SIZE $FILE" >&5
		done 3>"$TMP/md5sums" 4>"$TMP/sha1sums" 5>"$TMP/sha256sums"
		echo "MD5Sum:"
		cat "$TMP/md5sums"
		echo "SHA1Sum:"
		cat "$TMP/sha1sums"
		echo "SHA256Sum:"
		cat "$TMP/sha256sums"

	} >"$VARCACHE/dists/$DIST-$DATE/Release"

	# Sign the top-level `Release` file with `gpg`.
	gpg -sba -u"$GPG" -o"$VARCACHE/dists/$DIST-$DATE/Release.gpg" \
		"$VARCACHE/dists/$DIST-$DATE/Release" || {
		cat <<EOF
# [freight] couldn't sign the repository, perhaps you need to run
# [freight] gpg --gen-key and update the GPG setting in /etc/freight.conf
# [freight] (see freight(5) for more information)
EOF
		rm -rf "$VARCACHE/dists/$DIST-$DATE"
		exit 1
	}
	mkdir -m700 -p "$TMP/gpg"
	gpg --export -a "$GPG" | tee "$VARCACHE/pubkey.gpg" |
	gpg --homedir "$TMP/gpg" --import
	mv "$TMP/gpg/pubring.gpg" "$VARCACHE/keyring.gpg"

	# Move the symbolic link for this distro to this build.
	ln -s "$DIST-$DATE" "$VARCACHE/dists/$DIST-$DATE-"
	OLD="$(readlink "$VARCACHE/dists/$DIST" || true)"
	mv -T "$VARCACHE/dists/$DIST-$DATE-" "$VARCACHE/dists/$DIST"
	[ -z "$OLD" ] || rm -rf "$VARCACHE/dists/$OLD"

}

# Clean up old packages in the pool.
apt_clean() {
	find "$VARCACHE/pool" -links 1 -delete || true
}
