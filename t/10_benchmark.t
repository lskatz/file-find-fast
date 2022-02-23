#!/usr/bin/env perl

use strict;
use warnings;
use Benchmark ':all';
use Test::More 'no_plan';
use File::Basename qw/dirname/;

use FindBin qw/$RealBin/;
use Data::Dumper;
use lib "$RealBin/../lib";
use lib "$RealBin/../lib/perl5"; # compatibility with cpanm --installdeps . -l .
use File::Find::Fast ();
use File::Find ();
use Path::Iterator::Rule ();

my $thisDir = dirname($0);
my $filesDir = "$thisDir/files";

# Vanilla GNU find program
sub gnuFind{
  my @files = `find $filesDir`;
  chomp(@files);
  return \@files;
}
# This package's program
sub fileFindFast{
  my $files = File::Find::Fast::find($filesDir);
  return $files;
}
# Default perl File::Find
sub fileFind{
  my @files = ();
  File::Find::find({wanted=>sub{
    push(@files,$File::Find::name);
  }, no_chdir=>1}, $filesDir);
  return \@files;
}

# PIR options for fastest possible finding, see:
#   https://metacpan.org/pod/Path::Iterator::Rule#PERFORMANCE
my $pirOptions = {loop_safe=>0, sorted=>0, depthfirst=>-1, error_handler=>undef};
# PIR finding function but it recreates the rule object each time
sub pirFresh{
  my $rule = Path::Iterator::Rule->new;
  my @file = $rule->all($filesDir,$pirOptions);
  return \@file;
}
# PIR finding function again but not recreating the rule object
my $globalRule = Path::Iterator::Rule->new;
sub pirReused{
  my @file = $globalRule->all($filesDir, $pirOptions);
  return \@file;
}

# initial check
my $gnuFind = gnuFind();
my $fileFindFast = fileFindFast();
my $fileFind = fileFind();
my $pirFresh = pirFresh();
my $pirReused= pirReused();
#note Dumper [$gnuFind, $fileFindFast, $fileFind];
is_deeply($fileFindFast, $gnuFind, "File::Find::Fast");
is_deeply($fileFind, $gnuFind, "File::Find");
is_deeply([sort @$pirFresh], $gnuFind, "Path::Iterator::Rule");
is_deeply([sort @$pirReused], $gnuFind, "Path::Iterator::Rule2");

cmpthese(1000, { 
    'gnuFind'          => sub { gnuFind() },
    'File::Find::Fast' => sub { fileFindFast() },
    'File::Find'       => sub { fileFind() },
    'Path::Iterator::Rule'  => sub { pirFresh() },
    'Path::Iterator::Rule2'  => sub { pirReused() },
});

