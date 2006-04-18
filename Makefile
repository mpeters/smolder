# Smolder master Makefile.  The following targets are supported: 
#
#   all           - Show help text
#
#   test          - runs the test suite
#
#   db            - recreates databases by calling bin/smolder_createdb
#
#   start         - start the smolder services
#
#   restart       - restart the smolder services
#
#   stop          - stop the smolder services
#
#   dist          - build a Smolder distribution for release
#
#   clean         - remove the results of a build
#
#   empty_trash   - clean out the tmp/ directory and any .bak or ~ files
#
#   build         - build required modules and Apache/mod_perl from source
#
#   tidy          - run perltidy on all Smolder *.pm and *.t files. Probably not
#                   what you want.  see tidy_modified instead.
#
#   tidy_modified - run perltidy on all modified *.pm and *.t files, as
#           reported by svn status


all:
	@echo "No default make target."

build:  clean
	bin/smolder_build

dist:
	bin/smolder_makedist

clean:
	- find lib/ -mindepth 1 | grep -v Smolder | grep -v svn | xargs rm -rf
	- find apache/ -mindepth 1 -maxdepth 1 | grep -v svn | xargs rm -rf
	- find swish-e/ -mindepth 1 -maxdepth 1 | grep -v svn | xargs rm -rf
	- find sqlite/ -mindepth 1 -maxdepth 1 | grep -v svn | xargs rm -rf
	- rm -f data/build.db

test:
	bin/smolder_test

db:
	bin/smolder_createdb --destroy

db_noq:
	bin/smolder_createdb --destroy --no_prompt

start:
	bin/smolder_ctl start

restart:
	bin/smolder_ctl restart

stop:
	bin/smolder_ctl stop

empty_trash:
	- find . \( -name '*.bak' -or -name '*~' \) -exec rm {} \;
	- find tmp/ -mindepth 1 -maxdepth 1 ! \( -name '.svn' -o -name '*.conf' -o -name '*.pid' \) -exec rm -rf {} \;

tidy:
	- find lib/Smolder/ -name '*.pm' | xargs perltidy -b -i=4 -pt=1 -ci=2 -ce -bt=1 -sbt=1 -l=100
	- find t/ -name '*.t' | xargs perltidy -b -i=4 -pt=1 -ci=2 -ce -bt=1 -sbt=1 -l=100

tidy_modified:
	svn -q status | grep '^M.*\.\(pm\|pl\|t\)$$' | cut -c 8- | xargs perltidy -i=4 -pt=1 -ci=2 -ce -bt=1 -sbt=1 -l=100

.PHONY : all dist test clean docs build upgrade
