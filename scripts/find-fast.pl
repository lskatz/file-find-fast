#!/usr/bin/env perl 

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Basename qw/basename/;
use File::Find::Fast qw/find_iterator $VERSION/;

# versioning comes from File::Find::Fast

local $0 = basename $0;
sub logmsg{local $0=basename $0; print STDERR "$0: @_\n";}
exit(main());

sub main{
  my $settings={};
  GetOptions($settings,qw(help quiet version)) or die $!;

  if($$settings{version}){
    print "$0 $VERSION\n";
    return 0;
  }

  usage() if($$settings{help} || !@ARGV);

  for my $dir(@ARGV){
    logmsg "Listing files from $dir" unless($$settings{quiet});
    findFast($dir);
  }

  return 0;
}

sub findFast{
  my($dir) = @_;

  my $numFiles = 0;

  my $it = find_iterator($dir);
  while(my $f = $it->()){
    print $f . "\n";
    $numFiles++;
  }

  return $numFiles;
}

sub usage{
  print "$0: lists all files in a directory
  Usage: $0 dir [dir2...]
  --quiet    Print fewer things to stderr
  --version  Print the version and exit
  --help     This useful help menu
  \n";
  exit 0;
}
