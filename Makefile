CC?=gcc
OFLAGS=-O1
CFLAGS=-O2 -Wall
OWL=ol-0.1.14
OWLSHA=8df96fcb16d666700984ba9db2767dbceba6f6d027623a19be72ea87ce44e15a
OWLURL=https://github.com/aoh/owl-lisp/releases/download/v0.1.14
PREFIX=/usr

everything: bin/led .parrot

.parrot: bin/led 
	cd test && ./run ../bin/led
	touch .parrot

# gcc takes a while on a raspberry. this is a lot faster.
fasltest: led.fasl bin/ol
	cd test && ./run  ../bin/ol -l ../led.fasl --

bin/led: led.c
	mkdir -p bin
	$(CC) $(CFLAGS) -o bin/led led.c

led.c: led/*.scm
	make bin/ol
	bin/ol $(OFLAGS) -o led.c led/led.scm

led.fasl: bin/ol led/*.scm
	make bin/ol
	bin/ol -o led.fasl led/led.scm

install: bin/led .parrot
	install -m 755 bin/led $(PREFIX)/bin

uninstall:
	rm -v $(PREFIX)/bin/led

bin/ol:
	mkdir -p bin tmp
	cd tmp; test -f $(OWL).c.gz || wget $(OWLURL)/$(OWL).c.gz
	shasum -a 256 tmp/$(OWL).c.gz | grep -q $(OWLSHA)
	gzip -d < tmp/$(OWL).c.gz > tmp/$(OWL).c
	cc -O2 -o bin/ol tmp/$(OWL).c

test: .parrot

clean:
	-rm led.c led.log test/*.out bin/led bin/ol tmp/$(OWL).c
	-rmdir bin

mrproper:
	make clean
	rm -rf tmp

.PHONY: mrproper clean test install uninstall fasltest everything
