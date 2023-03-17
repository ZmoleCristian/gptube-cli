PREFIX = /usr/local

gptube: gptube.sh
	cat gptube.sh > $@

	chmod +x $@

test: gptube.sh
	shellcheck -s sh gptube.sh

clean:
	rm -f gptube

install: gptube
	./installReq.sh
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp -f gptube $(DESTDIR)$(PREFIX)/bin
	chmod 755 $(DESTDIR)$(PREFIX)/bin/gptube

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/gptube

.PHONY: test clean install uninstall