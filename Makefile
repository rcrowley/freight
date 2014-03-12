VERSION=0.3.5
BUILD=1

prefix=/usr/local
bindir=${prefix}/bin
libdir=${prefix}/lib
sysconfdir=${prefix}/etc
mandir=${prefix}/share/man

all:

clean:
	rm -rf *.deb debian man/man*/*.html
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
	make install prefix=/usr sysconfdir=/etc DESTDIR=debian
	fpm -s dir -t deb \
		-n freight -v $(VERSION) --iteration $(BUILD) -a all \
		-d coreutils -d dash -d dpkg -d gnupg -d grep \
		-m "Richard Crowley <r@rcrowley.org>" \
		--url "https://github.com/rcrowley/freight" \
		--description "A modern take on the Debian archive." \
		-C debian .
	make uninstall prefix=/usr sysconfdir=/etc DESTDIR=debian

deploy:
	scp freight_$(VERSION)-$(BUILD)_all.deb root@rcrowley.org:
	ssh -t root@rcrowley.org "freight add freight_$(VERSION)-$(BUILD)_all.deb apt/squeeze apt/wheezy apt/sid apt/lucid apt/precise apt/quantal apt/raring apt/saucy apt/trusty && rm freight_$(VERSION)-$(BUILD)_all.deb && freight cache apt/squeeze apt/wheezy apt/sid apt/lucid apt/precise apt/quantal apt/raring apt/saucy apt/trusty"

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

.PHONY: all install uninstall deb deploy man gh-pages
