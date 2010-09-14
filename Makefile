prefix=/usr/local
sysconfdir=${prefix}/etc
mandir=${prefix}/share/man

VERSION=$(shell grep Version control | cut -d" " -f2)

all:

install:
	install -d $(DESTDIR)$(prefix)/bin
	install bin/freight bin/freight-add bin/freight-cache bin/freight-setup \
		$(DESTDIR)$(prefix)/bin/
	install -d $(DESTDIR)$(prefix)/lib/freight
	install -m644 lib/freight/*.sh $(DESTDIR)$(prefix)/lib/freight/
	install -d $(DESTDIR)$(sysconfdir)
	install -m644 etc/freight.conf.example $(DESTDIR)$(sysconfdir)/
	install -d $(DESTDIR)$(mandir)/man1
	install -m644 man/man1/freight-add.1 man/man1/freight-cache.1 \
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
		$(DESTDIR)$(mandir)/man1/freight-add.1 \
		$(DESTDIR)$(mandir)/man1/freight-cache.1 \
		$(DESTDIR)$(mandir)/man5/freight.5
	rmdir -p --ignore-fail-on-non-empty \
		$(DESTDIR)$(prefix)/bin \
		$(DESTDIR)$(prefix)/lib/freight \
		$(DESTDIR)$(sysconfdir) \
		$(DESTDIR)$(mandir)/man1 \
		$(DESTDIR)$(mandir)/man5

deb:
ifeq (root, $(shell whoami))
	debra create debian control
	make install DESTDIR=debian prefix=/usr sysconfdir=/etc
	chown -R root:root debian
	debra build debian freight_$(VERSION)_all.deb
	debra destroy debian
else
	@echo "You must be root to build a Debian package."
endif

man:
	find man -name \*.ronn | xargs -n1 ronn \
		--manual=Freight --style=toc

docs:
	for SH in $$(find bin lib -type f -not -name \*.html); do \
		shocco $$SH >$$SH.html; \
	done

gh-pages: man docs
	mkdir -p gh-pages
	find man -name \*.html | xargs -I__ mv __ gh-pages/
	for HTML in $$(find bin lib -name \*.html -printf %H/%P\\n); do \
		mkdir -p gh-pages/$$(dirname $$HTML); \
		mv $$HTML gh-pages/$$HTML; \
	done
	git checkout -q gh-pages
	cp -R gh-pages/* ./
	rm -rf gh-pages
	git add .
	git commit -m "Rebuilt manual."
	git push origin gh-pages
	git checkout -q master

.PHONY: all install uninstall man docs gh-pages
