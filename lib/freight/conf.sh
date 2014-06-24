# Freight configuration.

# Default directories for the Freight library and Freight cache.  Your
# web server's document root should be `$VARCACHE`.
VARLIB="/var/lib/freight"
VARCACHE="/var/cache/freight"

# Default architectures.
ARCHS="i386 amd64"

# Default `Origin` and `Label` fields for `Release` files.
ORIGIN="Freight"
LABEL="Freight"

CACHE="off"

SYMLINKS="off"

# Source all existing configuration files from lowest- to highest-priority.
PREFIX="$(dirname $(dirname $0))"
if [ "$PREFIX" = "/usr" ]
then [ -f "/etc/freight.conf" ] && . "/etc/freight.conf"
else [ -f "$PREFIX/etc/freight.conf" ] && . "$PREFIX/etc/freight.conf"
fi
[ -f "$HOME/.freight.conf" ] && . "$HOME/.freight.conf"
DIRNAME="$PWD"
while true
do
	[ -f "$DIRNAME/etc/freight.conf" ] && . "$DIRNAME/etc/freight.conf" && break
	[ -f "$DIRNAME/.freight.conf" ] && . "$DIRNAME/.freight.conf" && break
	[ "$DIRNAME" = "/" ] && break
	DIRNAME="$(dirname "$DIRNAME")"
done
[ "$FREIGHT_CONF" -a -f "$FREIGHT_CONF" ] && . "$FREIGHT_CONF"
if [ "$CONF" ]
then
    if [ -f "$CONF" ]
    then . "$CONF"
    else
        echo "# [freight] $CONF does not exist" >&2
        exit 1
    fi
fi

# Normalize directory names.
VARLIB=${VARLIB%%/}
VARCACHE=${VARCACHE%%/}
