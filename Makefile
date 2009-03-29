# Smolder master Makefile.  The following targets are supported: 
#
#   all           - Show help text
#
#   build         - build Smolder
#
#   clean         - remove the results of a build, tests etc
#
#   test          - runs the test suite
#
#   db            - recreates databases by calling bin/smolder_createdb
#
#   tidy          - run perltidy on all Smolder *.pm and *.t files. Probably not
#                   what you want.  see tidy_modified instead.
#
#   tidy_modified - run perltidy on all modified *.pm and *.t files, as
#              		reported by svn status


all:
	@echo "No default make target."

build:
	perl Build.PL; ./Build

clean: build
	- rm -rf data/*
	- rm -rf logs/*
	- ./Build realclean

test: build
	./Build test

db: build
	./Build db

TIDY_ARGS = --backup-and-modify-in-place --indent-columns=4 --cuddled-else --maximum-line-length=100 --nooutdent-long-quotes --paren-tightness=2 --brace-tightness=2 --square-bracket-tightness=2
tidy:
	- find lib/Smolder/ -name '*.pm' | xargs perltidy -b -i=4 -pt=1 -ci=2 -ce -bt=1 -sbt=1 -l=100
	- find t/ -name '*.t' | xargs perltidy $(TIDY_ARGS)

tidy_modified:
	svn -q status | grep '^M.*\.\(pm\|pl\|t\)$$' | cut -c 8- | xargs perltidy $(TIDY_ARGS)

.PHONY : all build clean test db tidy tidy_modified
