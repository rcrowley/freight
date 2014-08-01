# Freight

A modern take on the Debian archive.

## Usage

Install Freight and create a minimal configuration in `/usr/local/etc/freight.conf` or `/etc/freight.conf` as appropriate containing the name of your GPG key:

	GPG="example@example.com"

Add packages to particular distros:

	freight add foobar_1.2.3-1_all.deb apt/squeeze apt/lucid apt/natty

Build the cache of all the files needed to be accepted as a Debian archive:

	freight cache

Serve `/var/cache/freight` via your favorite web server and install it as an APT source:

	echo "deb http://example.com $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/example.list
	sudo wget -O /etc/apt/trusted.gpg.d/example.gpg http://example.com/keyring.gpg
	sudo apt-get update
	sudo apt-get -y install foobar

## Installation

### From source

	git clone git://github.com/rcrowley/freight.git
	cd freight && make && sudo make install

### From a Debian archive

	echo "deb http://packages.rcrowley.org $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/rcrowley.list
	sudo wget -O /etc/apt/trusted.gpg.d/rcrowley.gpg http://packages.rcrowley.org/keyring.gpg
	sudo apt-get update
	sudo apt-get -y install freight

### From Fedora/EPEL repositories

EL users must first [configure EPEL](http://fedoraproject.org/wiki/EPEL/FAQ#How_can_I_install_the_packages_from_the_EPEL_software_repository.3F).

	yum -y install freight

## Documentation

* [Debian packaging for busy people](http://rcrowley.org/articles/packaging.html)

There's also [French documentation](http://blog.valouille.fr/2014/03/creer-un-depot-debian-signe-avec-freight/) assembled by Valérian Beaudoin.

## Manuals

* [`freight`(1)](http://rcrowley.github.com/freight/freight.1.html)
* [`freight-add`(1)](http://rcrowley.github.com/freight/freight-add.1.html)
* [`freight-cache`(1)](http://rcrowley.github.com/freight/freight-cache.1.html)
* [`freight`(5)](http://rcrowley.github.com/freight/freight.5.html)

## Contribute

Freight is [BSD-licensed](https://github.com/rcrowley/freight/blob/master/LICENSE)

* Source code: <https://github.com/rcrowley/freight>
* Issue tracker: <https://github.com/rcrowley/freight/issues>
* Wiki: <https://github.com/rcrowley/freight/wiki>
