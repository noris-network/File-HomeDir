#!/usr/bin/perl

# Main testing for File::HomeDir

# Testing "home directory" concepts is blood difficult, be delicate in
# your changes and don't forget to test on every OS at multiple versions
# (WinXP vs Win2003 etc) as both root and non-root users.

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}
use File::Spec::Functions ':ALL';
use Test::More;
use File::HomeDir;

# This module is destined for the core.
# Please do NOT use convenience modules
# use English; <-- don't do this

sub is_dir($) {
	my $dir = shift or return;
	return 1 if -d $dir;
	return unless -l $dir;
	$dir = readlink $dir or return;
	return -d $dir;
}





#####################################################################
# Environment Detection and Plan

# For what scenarios can we be sure that we have desktop/documents
my $NO_GETPWUID   = 0;
my $HAVEHOME      = 0;
my $HAVEDESKTOP   = 0;
my $HAVEMUSIC     = 0;
my $HAVEPICTURES  = 0;
my $HAVEVIDEOS    = 0;
my $HAVEDOCUMENTS = 0;
my $HAVEOTHERS    = 0;

# Various cases of things we should try to test for
# Top level is entire classes of operating system.
# Below that are more general things.
if ( $^O eq 'MSWin32' ) {
	$NO_GETPWUID   = 1;
	$HAVEHOME      = 1;
	$HAVEDESKTOP   = 1;
	$HAVEPICTURES  = 1;
	$HAVEDOCUMENTS = 1;
	$HAVEOTHERS    = 1;

	# My Music does not exist on Win2000
	require Win32;
	my @version = Win32::GetOSVersion();
	my $v       = ($version[4]||0)
	            + ($version[1]||0) * 0.001
	            + ($version[2]||0) * 0.000001;
	if ( $v <= 2.005000 ) {
		$HAVEMUSIC  = 0;
		$HAVEVIDEOS = 0;
	} else {
		$HAVEMUSIC  = 1;
		$HAVEVIDEOS = 0; # If we ever support "maybe" this is a maybe
	}

# System is unix-like

# Nobody users on all unix systems generally don't have home directories
} elsif ( getpwuid($<) eq 'nobody' ) {
	$HAVEHOME     = 0;
	$HAVEDESKTOP  = 0;
	$HAVEMUSIC    = 0;
	$HAVEPICTURES = 0;
	$HAVEVIDEOS   = 0;
	$HAVEOTHERS   = 0;

} elsif (
	$^O eq 'darwin'
) {
	# "Unixes with proper desktops" special cases
	if ( $ENV{AUTOMATED_TESTING} ) {
		# Automated testers on Mac (notably BINGOS) will often have
		# super stripped down testing users.
		$HAVEHOME      = 1;
		$HAVEDESKTOP   = 1;
		$HAVEMUSIC     = 0;
		$HAVEPICTURES  = 0;
		$HAVEVIDEOS    = 0;
		$HAVEDOCUMENTS = 0;
		$HAVEOTHERS    = 1;
	} elsif ( $< ) {
		# Normal user
		$HAVEHOME      = 1;
		$HAVEDESKTOP   = 1;
		$HAVEMUSIC     = 1;
		$HAVEPICTURES  = 1;
		$HAVEVIDEOS    = 1;
		$HAVEDOCUMENTS = 1;
		$HAVEOTHERS    = 1;
	} else {
		# Root can only be relied on to have a home
		$HAVEHOME      = 1;
		$HAVEDESKTOP   = 0;
		$HAVEMUSIC     = 0;
		$HAVEPICTURES  = 0;
		$HAVEVIDEOS    = 0;
		$HAVEDOCUMENTS = 0;
		$HAVEOTHERS    = 0;
	}

} elsif ( $File::HomeDir::IMPLEMENTED_BY eq 'File::HomeDir::FreeDesktop' ) {
	# On FreeDesktop we can't trust people to have a desktop (annoyingly)
	$HAVEHOME      = 1;
	$HAVEDESKTOP   = 0;
	$HAVEMUSIC     = 0;
	$HAVEVIDEOS    = 0;
	$HAVEPICTURES  = 0;
	$HAVEDOCUMENTS = 0;
	$HAVEOTHERS    = 0;

} else {
	# Default to traditional Unix
	$HAVEHOME      = 1;
	$HAVEDESKTOP   = 1;
	$HAVEMUSIC     = 1;
	$HAVEPICTURES  = 1;
	$HAVEVIDEOS    = 1;
	$HAVEDOCUMENTS = 1;
	$HAVEOTHERS    = 1;
}

plan tests => 39;





#####################################################################
# Test invalid uses

eval {
	home(undef);
};
like( $@, qr{Can\'t use undef as a username}, 'home(undef)' );





#####################################################################
# API Test

# Check the methods all exist
foreach ( qw{ home desktop documents music pictures videos data } ) {
	can_ok( 'File::HomeDir', "my_$_" );
	can_ok( 'File::HomeDir', "users_$_" );
}





#####################################################################
# Main Tests

# Find this user's homedir
my $home = home();
if ( $HAVEHOME ) {
	ok( !!($home and is_dir $home), 'Found our home directory' );
} else {
	is( $home, undef, 'Confirmed no home directory' );
}

# this call is not tested:
# File::HomeDir->home

# Find this user's home explicitly
my $my_home = File::HomeDir->my_home;
if ( $HAVEHOME ) {
	ok( !!($home and is_dir $home), 'Found our home directory' );
} else {
	is( $home, undef, 'Confirmed no home directory' );
}

# check that $ENV{HOME} is honored if set
{
  local $ENV{HOME} = rel2abs('.');
  is( File::HomeDir->my_home(), $ENV{HOME}, "my_home() returns $ENV{HOME}" );
}

my $my_home2 = File::HomeDir::my_home();
if ( $HAVEHOME ) {
	ok( !!($my_home2 and is_dir $my_home2), 'Found our home directory' );
} else {
	is( $home, undef, 'No home directory, as expected' );
}
is( $home, $my_home2, 'Different APIs give same results' );

# shall we test using -w if the home directory is writable ?

# Find this user's documents
SKIP: {
	my $my_documents  = File::HomeDir->my_documents;
	my $my_documents2 = File::HomeDir::my_documents();
	is( $my_documents, $my_documents2, 'Different APIs give the same results' );

	skip("Cannot assume existance of documents", 2) unless $HAVEDOCUMENTS;
	ok( !!($my_documents  and is_dir $my_documents), 'Found our documents directory' );
	ok( !!($my_documents2 and $my_documents2),   'Found our documents directory' );
}

# Find this user's pictures directory
SKIP: {
	skip("Cannot assume existance of pictures", 3) unless $HAVEPICTURES;
	my $my_pictures  = File::HomeDir->my_pictures;
	my $my_pictures2 = File::HomeDir::my_pictures();
	is( $my_pictures, $my_pictures2, 'Different APIs give the same results' );
	ok( !!($my_pictures  and is_dir $my_pictures),  'Our pictures directory exists' );
	ok( !!($my_pictures2 and is_dir $my_pictures2), 'Our pictures directory exists' );
}

# Find this user's music directory
SKIP: {
	skip("Cannot assume existance of music", 3) unless $HAVEMUSIC;
	my $my_music  = File::HomeDir->my_music;
	my $my_music2 = File::HomeDir::my_music();
	is( $my_music, $my_music2, 'Different APIs give the same results' );
	ok( !!($my_music  and is_dir $my_music),  'Our music directory exists' );
	ok( !!($my_music2 and is_dir $my_music2), 'Our music directory exists' );
}

# Find this user's video directory
SKIP: {
	skip("Cannot assume existance of videos", 3) unless $HAVEVIDEOS;
	my $my_videos  = File::HomeDir->my_videos;
	my $my_videos2 = File::HomeDir::my_videos();
	is( $my_videos, $my_videos2, 'Different APIs give the same results' );
	ok( !!($my_videos  and is_dir $my_videos),  'Our videos directory exists' );
	ok( !!($my_videos2 and is_dir $my_videos2), 'Our videos directory exists' );
}

# Desktop cannot be assumed in all environments
SKIP: {
	skip("Cannot assume existance of desktop", 3 ) unless $HAVEDESKTOP;

	# Find this user's desktop data
	my $my_desktop  = File::HomeDir->my_desktop;
	my $my_desktop2 = File::HomeDir::my_desktop();
	is( $my_desktop, $my_desktop2, 'Different APIs give the same results' );
	ok( !!($my_desktop  and is_dir $my_desktop),  'Our desktop directory exists' );
	ok( !!($my_desktop2 and is_dir $my_desktop2), 'Our desktop directory exists' );
}

# Find this user's local data
SKIP: {
	skip("Cannot assume existance of application data", 3) unless $HAVEOTHERS;
	my $my_data  = File::HomeDir->my_data;
	my $my_data2 = File::HomeDir::my_data();
	is( $my_data, $my_data2, 'Different APIs give the same results' );
	ok( !!($my_data  and is_dir $my_data),  'Found our local data directory' );
	ok( !!($my_data2 and is_dir $my_data2), 'Found our local data directory' );
}

# Shall we check name space pollution by testing functions in main before
# and after calling use ?

# On platforms other than windows, find root's homedir
SKIP: {
	if ( $^O eq 'MSWin32' or $^O eq 'darwin') {
		skip("Skipping root test on $^O", 1 );
	}

	# Determine root
	my $root = getpwuid(0);
	unless ( $root ) {
		skip("Skipping, can't determine root", 1 );
	}

	# Get root's homedir
	my $root_home1 = home($root);
	ok( !!($root_home1 and is_dir $root_home1), "Found root's home directory" );
}
