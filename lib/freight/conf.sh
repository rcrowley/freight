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

# Parse the configuration file for overrides.  Typically, the config file
# would be found at `$prefix/etc/freight.conf` but a special exception is
# made when `$prefix` is `/usr`.  In that case, the config file is
# `/etc/freight.conf`.
if [ -z "$CONF" ]
then
	CONF="$(dirname $(dirname $0))/etc/freight.conf"
	[ "$CONF" = "/usr/etc/freight.conf" ] && CONF="/etc/freight.conf"
fi
. "$CONF"

# Normalize directory names.
VARLIB=${VARLIB%%/}
VARCACHE=${VARCACHE%%/}
