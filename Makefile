CC?=gcc
OFLAGS=-O2
CFLAGS=-O2 -Wall
OWLVERSION=0.1.13
OL?=owl-lisp-$(OWLVERSION)/bin/vm owl-lisp-$(OWLVERSION)/fasl/init.fasl

everything: bin/led .parrot

.parrot: bin/led 
	cd test && ./run ../bin/led
	touch .parrot

# gcc takes a while on a raspberry. this is a lot faster.
fasltest: led.fasl
	cd test && ./run  ../owl-lisp-$(OWLVERSION)/bin/vm ../led.fasl

bin/led: led.c
	mkdir -p bin
	$(CC) $(CFLAGS) -o bin/led led.c

led.c: led/led.scm led/terminal.scm
	make get-owl
	$(OL) $(OFLAGS) -o led.c led/led.scm

led.fasl: led/led.scm led/terminal.scm
	$(OL) -o led.fasl led/led.scm

install: bin/led .parrot
	install -m 755 bin/led /usr/bin

get-owl:
	test -d owl-lisp-$(OWLVERSION) || curl -L https://github.com/aoh/owl-lisp/archive/v$(OWLVERSION).tar.gz | tar -zxvf -
	cd owl-lisp-$(OWLVERSION) && make bin/vm

test: .parrot

clean:
	-rm led.c led.log led test/*.out bin/led
	-rmdir bin
	-cd owl-lisp-$(OWLVERSION) && make clean

mrproper:
	make clean
	rm -rf owl-lisp-$(OWLVERSION)

