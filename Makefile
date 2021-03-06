#
#  Copyright 2012-2013 Diomidis Spinellis
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

INSTPREFIX?=/usr/local

ifdef DEBUG
CFLAGS=-g -DDEBUG -Wall
else
CFLAGS=-O -Wall
endif

EXECUTABLES=sgsh sgsh-tee sgsh-writeval sgsh-readval sgsh-monitor sgsh-httpval \
	sgsh-ps sgsh-merge-sum

# Manual pages
MANSRC=$(wildcard *.1)
MANPDF=$(patsubst %.1,%.pdf,$(MANSRC))
MANHTML=$(patsubst %.1,%.html,$(MANSRC))

# Web files
EXAMPLES=$(patsubst example/%,%,$(wildcard example/*.sh))
EGPNG=$(patsubst %.sh,png/%-pretty.png,$(EXAMPLES))
WEBPNG=$(EGPNG) debug.png profile.png
WEBDIST=../../../pubs/web/home/sw/sgsh/

%.png: %.sh
	./sgsh -g pretty $< | dot -Tpng >$@

png/%-pretty.png: example/%.sh
	./sgsh -g pretty $< | dot -Tpng >$@

%.pdf: %.1
	groff -man -Tps $< | ps2pdf - $@

%.html: %.1
	groff -man -Thtml $< >$@

all: $(EXECUTABLES)

sgsh-readval: sgsh-readval.c kvstore.c

sgsh-httpval: sgsh-httpval.c kvstore.c

test-sgsh: $(EXECUTABLES)
	./test-sgsh.sh

test-tee: sgsh-tee charcount test-tee.sh
	./test-tee.sh

test-merge-sum: sgsh-merge-sum.pl test-merge-sum.sh
	./test-merge-sum.sh

test-kvstore: test-kvstore.sh
	# Make versions that will exercise the buffers
	$(MAKE) clean
	$(MAKE) DEBUG=1
	./test-kvstore.sh
	# Remove the debug build versions
	$(MAKE) clean

sgsh: sgsh.pl
	perl -c sgsh.pl
	install sgsh.pl sgsh

sgsh-ps: sgsh-ps.pl
	! perl -e 'use JSON' 2>/dev/null || perl -c sgsh-ps.pl
	install sgsh-ps.pl sgsh-ps

sgsh-merge-sum: sgsh-merge-sum.pl
	perl -c sgsh-merge-sum.pl
	install sgsh-merge-sum.pl sgsh-merge-sum

charcount: charcount.sh
	install charcount.sh charcount

allpng: sgsh
	for i in example/*.sh ; do \
		./sgsh -g pretty $$i | dot -Tpng >png/`basename $$i .sh`-pretty.png ; \
		./sgsh -g pretty-full $$i | dot -Tpng >png/`basename $$i .sh`-pretty-full.png ; \
		./sgsh -g plain $$i | dot -Tpng >png/`basename $$i .sh`-plain.png ; \
	done
	# Outdate example files that need special processing
	touch -r example/ft2d.sh png/ft2d-pretty.png
	touch -r diagram/NMRPipe-pretty-full.dot png/NMRPipe-pretty.png

# Regression test based on generated output files
test-regression:
	# Sort files by size to get the easiest problems first
	# Generated dot graphs
	for i in `ls -rS example/*.sh` ; do \
		perl sgsh.pl -g plain $$i >test/regression/graphs/`basename $$i .sh`.test ; \
		diff -b test/regression/graphs/`basename $$i .sh`.* || exit 1 ; \
	done
	# Generated code
	for i in `ls -rS example/*.sh` ; do \
		perl sgsh.pl -o - $$i >test/regression/scripts/`basename $$i .sh`.test ; \
		diff -b test/regression/scripts/`basename $$i .sh`.* || exit 1 ; \
	done
	# Error messages
	for i in test/regression/errors/*.sh ; do \
		! /usr/bin/perl sgsh.pl -o /dev/null $$i 2>test/regression/errors/`basename $$i .sh`.test || exit 1; \
		diff -b test/regression/errors/`basename $$i .sh`.{ok,test} || exit 1 ; \
	done
	# Warning messages
	for i in test/regression/warnings/*.sh ; do \
		/usr/bin/perl sgsh.pl -o /dev/null $$i 2>test/regression/warnings/`basename $$i .sh`.test || exit 1; \
		diff -b test/regression/warnings/`basename $$i .sh`.{ok,test} || exit 1 ; \
	done

# Seed the regression test data
seed-regression:
	for i in example/*.sh ; do \
		echo $$i ; \
		/usr/bin/perl sgsh.pl -o - $$i >test/regression/scripts/`basename $$i .sh`.ok ; \
		/usr/bin/perl sgsh.pl -g plain $$i >test/regression/graphs/`basename $$i .sh`.ok ; \
	done
	for i in test/regression/errors/*.sh ; do \
		echo $$i ; \
		! /usr/bin/perl sgsh.pl -o /dev/null $$i 2>test/regression/errors/`basename $$i .sh`.ok ; \
	done
	for i in test/regression/warnings/*.sh ; do \
		echo $$i ; \
		/usr/bin/perl sgsh.pl -o /dev/null $$i 2>test/regression/warnings/`basename $$i .sh`.ok ; \
	done

clean:
	rm -f *.o *.exe $(EXECUTABLES) $(MANPDF) $(MANHTML) $(EGPNG)

install: $(EXECUTABLES)
	install $(EXECUTABLES) $(INSTPREFIX)/bin
	install -m 644 $(MANSRC) $(INSTPREFIX)/share/man/man1

web: $(MANPDF) $(MANHTML) $(WEBPNG)
	perl -n -e 'if (/^<!-- #!(.*) -->/) { system("$$1"); } else { print; }' index.html >$(WEBDIST)/index.html
	cp $(MANHTML) $(MANPDF) $(WEBDIST)
	cp $(WEBPNG) $(WEBDIST)

# Debugger examples
debug-word-properties: sgsh
	cat /usr/share/dict/words | ./sgsh -d -p . example/word-properties.sh

debug-web-log-report: sgsh
	gzip -dc eval/clarknet_access_log_Aug28.gz | ./sgsh -d -p . example/web-log-report.sh

# Diagrams that require special processing
png/ft2d-pretty.png: example/ft2d.sh
	./sgsh -g pretty $< | dot -Tpng | pngtopnm >top.pnm
	./sgsh -g pretty $< | sed '1,/^}/d' | dot -Tpng | pngtopnm | pnmcat -topbottom top.pnm - | pnmtopng >$@
	rm top.pnm

png/NMRPipe-pretty.png: diagram/NMRPipe-pretty-full.dot
	dot -Tpng $< >png/NMRPipe-pretty.png
