VERSION=0.0.9
BUILD=1

prefix=/usr/local
bindir=${prefix}/bin
sysconfdir=${prefix}/etc
mandir=${prefix}/share/man

all:

clean:
	rm -f *.deb

install:
	install -d $(DESTDIR)$(prefix)/bin
	install bin/freight bin/freight-add bin/freight-cache bin/freight-setup \
		$(DESTDIR)$(prefix)/bin/
	install -d $(DESTDIR)$(prefix)/lib/freight
	install -m644 lib/freight/*.sh $(DESTDIR)$(prefix)/lib/freight/
	install -d $(DESTDIR)$(sysconfdir)
	install -m644 etc/freight.conf.example $(DESTDIR)$(sysconfdir)/
	install -d $(DESTDIR)$(mandir)/man1
	install -m644 \
		man/man1/freight.1 \
		man/man1/freight-add.1 \
		man/man1/freight-cache.1 \
		$(DESTDIR)$(mandir)/man1/
	install -d $(DESTDIR)$(mandir)/man5
	install -m644 man/man5/freight.5 $(DESTDIR)$(mandir)/man5/

uninstall:
	rm -f \
		$(DESTDIR)$(prefix)/bin/freight \
		$(DESTDIR)$(prefix)/bin/freight-add \
		$(DESTDIR)$(prefix)/bin/freight-cache \
		$(DESTDIR)$(prefix)/bin/freight-setup \
		$(DESTDIR)$(prefix)/lib/freight/*.sh \
		$(DESTDIR)$(sysconfdir)/freight.conf.example \
		$(DESTDIR)$(mandir)/man1/freight.1 \
		$(DESTDIR)$(mandir)/man1/freight-add.1 \
		$(DESTDIR)$(mandir)/man1/freight-cache.1 \
		$(DESTDIR)$(mandir)/man5/freight.5
	rmdir -p --ignore-fail-on-non-empty \
		$(DESTDIR)$(prefix)/bin \
		$(DESTDIR)$(prefix)/lib/freight \
		$(DESTDIR)$(sysconfdir) \
		$(DESTDIR)$(mandir)/man1 \
		$(DESTDIR)$(mandir)/man5

build:
	make install prefix=/usr DESTDIR=debian
	fpm -s dir -t deb -C debian \
		-n freight -v $(VERSION)-$(BUILD) -a all \
		-d coreutils -d dash -d dpkg -d gnupg -d grep \
		-m "Richard Crowley <r@rcrowley.org>" \
		--url "https://github.com/rcrowley/freight" \
		--description "A modern take on the Debian archive."
	make uninstall prefix=/usr DESTDIR=debian

deploy:
	scp -i ~/production.pem freight_$(VERSION)-$(BUILD)_all.deb ubuntu@packages.devstructure.com:
	ssh -i ~/production.pem -t ubuntu@packages.devstructure.com "sudo freight add freight_$(VERSION)-$(BUILD)_all.deb apt/lenny apt/squeeze apt/lucid apt/maverick apt/natty && rm freight_$(VERSION)-$(BUILD)_all.deb && sudo freight cache apt/lenny apt/squeeze apt/lucid apt/maverick apt/natty"

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
