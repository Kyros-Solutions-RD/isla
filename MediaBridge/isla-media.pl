#!/usr/bin/perl
# Isla media bridge loader.
# Loads libIslaMediaBridge.dylib inside an Apple-signed interpreter so the
# bridge can read the system "Now Playing" session, then hands control to
# the requested entry point. Usage: isla-media.pl <dylib> <symbol>
use strict;
use warnings;
use DynaLoader;

my ($library, $symbol) = @ARGV;
die "usage: isla-media.pl <dylib> <symbol>\n" unless defined $library && defined $symbol;
die "bridge not found: $library\n" unless -e $library;

my $handle = DynaLoader::dl_load_file($library, 0)
  or die "unable to load bridge: " . DynaLoader::dl_error() . "\n";
my $entry = DynaLoader::dl_find_symbol($handle, $symbol)
  or die "unknown entry point: $symbol\n";

DynaLoader::dl_install_xsub("main::isla_entry", $entry);
isla_entry();
exit 0;
