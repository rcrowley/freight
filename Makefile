VERSION=0.3.10
BUILD=1

SH=dash

prefix=/usr/local
bindir=${prefix}/bin
libdir=${prefix}/lib
sysconfdir=${prefix}/etc
mandir=${prefix}/share/man

all:

clean:
	rm -rf *.deb deb man/man*/*.html test/tmp
	find . -name '*~' -delete

install: install-bin install-lib install-man install-sysconf

install-bin:
	find bin -type f -printf %P\\0 | xargs -0r -I__ install -D bin/__ $(DESTDIR)$(bindir)/__

install-lib:
	find lib -type f -printf %P\\0 | xargs -0r -I__ install -m644 -D lib/__ $(DESTDIR)$(libdir)/__

install-man:
	find man -type f -name \*.[12345678] -printf %P\\0 | xargs -0r -I__ install -m644 -D man/__ $(DESTDIR)$(mandir)/__
	find man -type f -name \*.[12345678] -printf %P\\0 | xargs -0r -I__ gzip $(DESTDIR)$(mandir)/__

install-sysconf:
	find etc -type f -not -name freight.conf -printf %P\\0 | xargs -0r -I__ install -m644 -D etc/__ $(DESTDIR)$(sysconfdir)/__

uninstall: uninstall-bin uninstall-lib uninstall-man uninstall-sysconf

uninstall-bin:
	find bin -type f -printf %P\\0 | xargs -0r -I__ rm -f $(DESTDIR)$(bindir)/__
	rmdir -p --ignore-fail-on-non-empty $(DESTDIR)$(bindir) || true

uninstall-lib:
	find lib -type f -printf %P\\0 | xargs -0r -I__ rm -f $(DESTDIR)$(libdir)/__
	find lib -depth -mindepth 1 -type d -printf %P\\0 | xargs -0r -I__ rmdir $(DESTDIR)$(libdir)/__ || true
	rmdir -p --ignore-fail-on-non-empty $(DESTDIR)$(libdir) || true

uninstall-man:
	find man -type f -name \*.[12345678] -printf %P\\0 | xargs -0r -I__ rm -f $(DESTDIR)$(mandir)/__.gz
	find man -depth -mindepth 1 -type d -printf %P\\0 | xargs -0r -I__ rmdir $(DESTDIR)$(mandir)/__ || true
	rmdir -p --ignore-fail-on-non-empty $(DESTDIR)$(mandir) || true

uninstall-sysconf:
	find etc -type f -printf %P\\0 | xargs -0r -I__ rm -f $(DESTDIR)$(sysconfdir)/__
	find etc -depth -mindepth 1 -type d -printf %P\\0 | xargs -0r -I__ rmdir $(DESTDIR)$(sysconfdir)/__ || true
	rmdir -p --ignore-fail-on-non-empty $(DESTDIR)$(sysconfdir) || true

build:
	make install prefix=/usr sysconfdir=/etc DESTDIR=deb
	fpm -s dir -t deb \
		-n freight -v $(VERSION) --iteration $(BUILD) -a all \
		-d coreutils -d dash -d dpkg -d gnupg -d grep \
		-m "Richard Crowley <r@rcrowley.org>" \
		--url "https://github.com/freight-team/freight" \
		--description "A modern take on the Debian archive." \
		-C deb .
	make uninstall prefix=/usr sysconfdir=/etc DESTDIR=deb

man:
	find man -name \*.ronn | xargs -n1 ronn --manual=Freight --style=toc

docs:
	for SH in $$(find bin lib -type f -not -name \*.html); do \
		shocco $$SH >$$SH.html; \
	done

gh-pages: man
	mkdir -p gh-pages
	find man -name \*.html | xargs -I__ mv __ gh-pages/
	git checkout -q gh-pages
	cp -R gh-pages/* ./
	rm -rf gh-pages
	git add .
	git commit -m "Rebuilt manual."
	git push origin gh-pages
	git checkout -q master

test/tmp/bats:
	git clone --depth 1 https://github.com/sstephenson/bats.git test/tmp/bats

test/tmp/bats-assert:
	git clone --depth 1 https://github.com/jasonkarns/bats-assert.git test/tmp/bats-assert

test/tmp/bin:
	mkdir -p test/tmp/bin

test/tmp/bin/sh: test/tmp/bin
	ln -sf $$(which $(SH)) test/tmp/bin/sh

check: test/tmp/bats test/tmp/bats-assert test/tmp/bin/sh
	PATH=test/tmp/bin/:$$PATH test/tmp/bats/bin/bats test/

.PHONY: all clean install uninstall build man docs gh-pages check
