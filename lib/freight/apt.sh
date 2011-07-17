# Fetch the given field from the package's control file.
apt_info() {
	egrep -i "^$2:" "$1" | cut -d: -f2 | cut -c2-
}

# Print the package name from the given control file.
apt_name() {
	apt_info "$1" Package
}

# Print the version from the given control file.
apt_version() {
	apt_info "$1" Version
}

# Print the architecture from the given control file.
apt_arch() {
	apt_info "$1" Architecture
}

# Print the source name from the given control file.
apt_sourcename() {
	source=$(apt_info "$1" Source)
	[ -z "$source" ] && source=$(apt_name "$1")
	echo "$source"
}

# Print the prefix the given control file should use in the pool.
apt_prefix() {
	source=$(apt_sourcename "$1")
	[ "$(echo "$source" | cut -c1-3)" = "lib" ] && C=4 || C=1
	echo "$source" | cut -c-$C
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

		# Verify this package by way of extracting its control information
		# to be used throughout this iteration of the loop.
		dpkg-deb -e "$VARLIB/apt/$DIST/$PATHNAME" "$TMP/DEBIAN" || {
			echo "# [freight] skipping invalid Debian package $PATHNAME" >&2
			continue
		}

		# Extract the component, if present, from the package's pathname.
		case "$PATHNAME" in
			*/*) COMP="${PATHNAME%%/*}" PACKAGE="${PATHNAME##*/}";;
			*) COMP="main" PACKAGE="$PATHNAME";;
		esac

		# Create all architecture-specific directories.  This will allow
		# packages marked `all` to actually be placed in all architectures.
		for ARCH in $ARCHS
		do
			mkdir -p "$DISTCACHE/$COMP/binary-$ARCH"
			touch "$DISTCACHE/$COMP/binary-$ARCH/Packages"
		done

		# Link or copy this package into this distro's `.refs` directory.
		REFS="$DISTCACHE/.refs/$COMP"
		mkdir -p "$REFS"
		ln "$VARLIB/apt/$DIST/$PATHNAME" "$REFS" ||
		cp "$VARLIB/apt/$DIST/$PATHNAME" "$REFS"

		# Package properties
		CONTROL="$TMP/DEBIAN/control"
		ARCH=$(apt_arch "$CONTROL")
		NAME=$(apt_name "$CONTROL")
		VERSION=$(apt_version "$CONTROL" | cut -d: -f2) # remove epoch
		PREFIX=$(apt_prefix "$CONTROL")
		SOURCE=$(apt_sourcename "$CONTROL")
		FILENAME="$NAME""_""$VERSION""_""$ARCH.deb"

		# Link this package into the pool.
		POOL="pool/$DIST/$COMP/$PREFIX/$SOURCE"
		mkdir -p "$VARCACHE/$POOL"
		if [ ! -f "$VARCACHE/$POOL/$FILENAME" ]
		then
			if [ "$PACKAGE" != "$FILENAME" ]
			then
				echo "# [freight] adding $PACKAGE to pool (as $FILENAME)" >&2
			else
				echo "# [freight] adding $PACKAGE to pool" >&2
			fi
			ln "$REFS/$PACKAGE" "$VARCACHE/$POOL/$FILENAME"
		fi

		# Build a list of the one-or-more `Packages` files to append with
		# this package's info.
		if [ "$ARCH" = "all" ]
		then
			FILES="$(find "$DISTCACHE/$COMP" -type f)"
		else
			FILES="$DISTCACHE/$COMP/binary-$ARCH/Packages"
		fi

		# Grab and augment the control file from this package.  Remove
		# `Size`, `MD5Sum`, etc. lines and replace them with newly
		# generated values.  Add the `Filename` field containing the
		# path to the package, starting with `pool/`.
		{
			grep . "$TMP/DEBIAN/control" \
				| grep -v "^(Essential|Filename|MD5Sum|SHA1|SHA256|Size)"
			cat <<EOF
Filename: $POOL/$FILENAME
MD5Sum: $(apt_md5 "$VARLIB/apt/$DIST/$PATHNAME")
SHA1: $(apt_sha1 "$VARLIB/apt/$DIST/$PATHNAME")
SHA256: $(apt_sha256 "$VARLIB/apt/$DIST/$PATHNAME")
Size: $(apt_filesize "$VARLIB/apt/$DIST/$PATHNAME")
EOF
			echo
		} | tee -a $FILES >/dev/null
		rm -rf "$TMP/DEBIAN"

	done
	COMPS="$(ls "$DISTCACHE")"

	# Build a `Release` file for each component and architecture.  `gzip`
	# the `Packages` file, too.
	for COMP in $COMPS
	do
		for ARCH in $ARCHS
		do
			cat >"$DISTCACHE/$COMP/binary-$ARCH/Release" <<EOF
Archive: $DIST
Component: $COMP
Origin: $ORIGIN
Label: $LABEL
Architecture: $ARCH
EOF
			gzip -c "$DISTCACHE/$COMP/binary-$ARCH/Packages" \
				>"$DISTCACHE/$COMP/binary-$ARCH/Packages.gz"
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
Components: $(echo "$COMPS" | tr \\n " ")
Architectures: $ARCHS
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
		done 3>"$TMP/md5sums" 4>"$TMP/sha1sums" 5>"$TMP/sha256sums"
		echo "MD5Sum:"
		cat "$TMP/md5sums"
		echo "SHA1Sum:"
		cat "$TMP/sha1sums"
		echo "SHA256Sum:"
		cat "$TMP/sha256sums"

	} >"$DISTCACHE/Release"

	# Sign the top-level `Release` file with `gpg`.
	gpg -sba -u"$GPG" -o"$DISTCACHE/Release.gpg" "$DISTCACHE/Release" || {
		cat <<EOF
# [freight] couldn't sign the repository, perhaps you need to run
# [freight] gpg --gen-key and update the GPG setting in /etc/freight.conf
# [freight] (see freight(5) for more information)
EOF
		rm -rf "$DISTCACHE"
		exit 1
	}

	# Generate `pubkey.gpg` containing the plaintext public key and
	# `keyring.gpg` containing a complete GPG keyring containing only
	# the appropriate public key.  `keyring.gpg` is appropriate for
	# copying directly to `/etc/apt/trusted.gpg.d`.
	mkdir -m700 -p "$TMP/gpg"
	gpg -q --export -a "$GPG" |
	tee "$VARCACHE/pubkey.gpg" |
	gpg -q --homedir "$TMP/gpg" --import
	mv "$TMP/gpg/pubring.gpg" "$VARCACHE/keyring.gpg"

	# Move the symbolic link for this distro to this build.
	ln -s "$DIST-$DATE" "$DISTCACHE-"
	OLD="$(readlink "$VARCACHE/dists/$DIST" || true)"
	mv -T "$DISTCACHE-" "$VARCACHE/dists/$DIST"
	[ -z "$OLD" ] || rm -rf "$VARCACHE/dists/$OLD"

}

# Clean up old packages in the pool.
apt_clean() {
	find "$VARCACHE/pool" -links 1 -delete || true
}
