CC = gcc
CFLAGS = -O2 -Wall

all: hello blink

hello: hello.c
	$(CC) $(CFLAGS) -o hello hello.c

blink: blink.c
	$(CC) $(CFLAGS) -o blink blink.c $(shell pkg-config --cflags --libs libgpiod)

install: all
	install -d $(DESTDIR)/usr/local/bin
	install -m 0755 hello $(DESTDIR)/usr/local/bin/
	install -m 0755 blink $(DESTDIR)/usr/local/bin/

clean:
	rm -f hello blink

.PHONY: all install clean
