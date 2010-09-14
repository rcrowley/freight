prefix=/usr/local
sysconfdir=/usr/local/etc

all:

install:

uninstall:

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
