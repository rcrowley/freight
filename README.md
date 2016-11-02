# Freight

[![IRC channel](https://kiwiirc.com/buttons/irc.freenode.net/freight.png)](https://kiwiirc.com/client/irc.freenode.net/?#freight)
[![Build Status](https://travis-ci.org/freight-team/freight.svg?branch=master)](https://travis-ci.org/freight-team/freight)

A modern take on the Debian archive.

This repository has been forked (in the traditional sense of the word) from
Richard Crowley's [freight](https://github.com/rcrowley/freight) repository. A
fork had become necessary because the main project was not actively maintained
and serious issues had started to crop up. While fixes and improvements were
available in various freight GitHub forks, they were not merged to the main
project. This fork and the associated GitHub organization,
[freight-team](https://github.com/freight-team), attempts to fix these issues.

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

	git clone git://github.com/freight-team/freight.git
	cd freight && make && sudo make install

### From a Debian archive

	wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg|sudo apt-key add -
	echo "deb http://build.openvpn.net/debian/freight_team $(lsb_release -sc) main" | sudo tee  /etc/apt/sources.list.d/freight.list
	sudo apt-get update
	sudo apt-get -y install freight

### From a custom-made Debian package

First [install FPM](https://github.com/jordansissel/fpm). Then clone the freight
repository, build a package and install it:

	git clone git://github.com/freight-team/freight.git
	cd freight && make build
	sudo dpkg -i freight_<version>-<build>_all.deb

### From Fedora/EPEL repositories

EL users must first [configure EPEL](http://fedoraproject.org/wiki/EPEL/FAQ#How_can_I_install_the_packages_from_the_EPEL_software_repository.3F).

	yum -y install freight

## Documentation

* [Debian packaging for busy people](http://rcrowley.org/articles/packaging.html)

There's also [French documentation](http://blog.valouille.fr/2014/03/creer-un-depot-debian-signe-avec-freight/) assembled by Valérian Beaudoin.

## Manuals

* [`freight`(1)](http://freight-team.github.io/freight/freight.1.html)
* [`freight-add`(1)](http://freight-team.github.io/freight/freight-add.1.html)
* [`freight-cache`(1)](http://freight-team.github.io/freight/freight-cache.1.html)
* [`freight-clear-cache`(1)](http://freight-team.github.io/freight/freight-clear-cache.1.html)
* [`freight-init`(1)](http://freight-team.github.io/freight/freight-init.1.html)
* [`freight`(5)](http://freight-team.github.io/freight/freight.5.html)

## Contribute

Freight is [BSD-licensed](https://github.com/freight-team/freight/blob/master/LICENSE)

* Source code: <https://github.com/freight-team/freight>
* Issue tracker: <https://github.com/freight-team/freight/issues>
* Wiki: <https://github.com/freight-team/freight/wiki>

### Test suite

The Freight test suite can be executed by running `make check` from any git checkout of this repository.  git and GnuPG are required for most tests, and extended tests require apt.

Contributions should include a new test case where possible by extending one or more of the `test/*.bats` files.
