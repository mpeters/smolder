package Debian::Platform;
use warnings;
use strict;

use base 'Smolder::Platform';

# This method returns 1 if it can determine if this
# is a Debian system.  I couldn't find an official
# statement or definition anywhere that specified
# what made a Debian distribution, so please let me
# know if you have any ideas.  For now, I'm using
# the existence and contents of the /etc/debian_version
# file (check 4.7 of this FAQ):
# http://www.debian.org/doc/FAQ/ch-software.en.html
sub guess_platform() {
	if ( -e "/etc/debian_version" ) {
		return 1;
	} else {
		return 0;
	}
}

# Debian puts their include files in a different spot
sub include_dirs { ('/usr/lib') }

1;
