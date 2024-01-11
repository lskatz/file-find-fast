#!/usr/bin/env perl

use strict;
use warnings;
use Benchmark ':all';
use Test::More tests => 2;
use File::Basename qw/dirname/;

use FindBin qw/$RealBin/;
use Data::Dumper;
use lib "$RealBin/../lib";
use lib "$RealBin/../lib/perl5"; # compatibility with cpanm --installdeps . -l .
use File::Find::Fast ();
use File::Find ();
use File::Path qw/rmtree/;
use File::Which qw/which/;
use Path::Iterator::Rule ();

my $thisDir = dirname($0);
my $shallowDir = "$thisDir/files";

my $OS = "nix";
if($^O =~ /mswin32/i){
  $OS = "win";
}
my $fd = which("fd") || which("fdfind") || "";
diag "fd was found at: '$fd'";

# Create a deep directory structure
sub create_deep_directory {
    my ($root_dir, $depth, $num_files) = @_;

    # Create the root directory if it doesn't exist
    mkdir $root_dir unless -e $root_dir;

    # Create deep directory structure
    create_structure($root_dir, $depth, $num_files);
}
sub create_structure {
    my ($dir, $depth, $num_files) = @_;

    return if $depth <= 0;

    # Create subdirectories
    for my $i (1 .. $num_files) {
        my $subdir = "$dir/dir_$i";
        mkdir $subdir;
        create_files($subdir, $num_files);
        create_structure($subdir, $depth - 1, $num_files);
    }
}
sub create_files {
    my ($dir, $num_files) = @_;

    for my $i (1 .. $num_files) {
        my $file = "$dir/file_$i.txt";
        open my $fh, '>', $file or die "Cannot create file $file: $!";
        close $fh;
    }
}

# Vanilla GNU find program
sub gnuFind{
  my($filesDir) = @_;
  my @files;
  if($OS eq 'win'){
    my $f = pirFresh();
    @files = @$f;
  } else {
    @files = `find $filesDir`;
  }
  chomp(@files);
  return \@files;
}
# This package's program
sub fileFindFast{
  my($filesDir) = @_;
  my $files = File::Find::Fast::find($filesDir);
  return $files;
}
# Default perl File::Find
sub fileFind{
  my($filesDir) = @_;
  my @files = ();
  File::Find::find({wanted=>sub{
    push(@files,$File::Find::name);
  }, no_chdir=>1}, $filesDir);
  return \@files;
}

# Iterator file find
sub fileFindFastIter{
  my($filesDir) = @_;
  my @files = ();
  my $it = File::Find::Fast::find_iterator($filesDir);
  while(my $f = $it->()){
    push(@files, $f);
  }
  return \@files;
}

# PIR options for fastest possible finding, see:
#   https://metacpan.org/pod/Path::Iterator::Rule#PERFORMANCE
my $pirOptions = {loop_safe=>0, sorted=>0, depthfirst=>-1, error_handler=>undef};
# PIR finding function but it recreates the rule object each time
sub pirFresh{
  my($filesDir) = @_;
  my $rule = Path::Iterator::Rule->new;
  my @file = $rule->all($filesDir,$pirOptions);
  return \@file;
}
# PIR finding function again but not recreating the rule object
my $globalRule = Path::Iterator::Rule->new;
sub pirReused{
  my($filesDir) = @_;
  my @file = $globalRule->all($filesDir, $pirOptions);
  return \@file;
}

sub fd{
  my($filesDir) = @_;
  my @file;
  if(!$fd){
    my $f = pirFresh();
    @file = @$f;
  }
  else {
    @file = `$fd . $filesDir`;
    #chomp(@file);

    # whitespace or trailing slash trimming
    @file = map{ s|[/\s+]+$||g; $_} @file;
    unshift(@file, $filesDir); # fd doesn't have the root dir for some reason
  }
  return \@file;
}

subtest 'Benchmark shallow' => sub{

  # initial check
  my $gnuFind = [sort @{ gnuFind($shallowDir) } ];
  my $fileFindFast = [sort @{ fileFindFast($shallowDir) } ];
  my $fileFindFastIter = [sort @{ fileFindFastIter($shallowDir) } ];
  my $fileFind = [sort @{fileFind($shallowDir) } ];
  my $pirFresh = [sort @{pirFresh($shallowDir) } ];
  my $pirReused= [sort @{pirReused($shallowDir) } ];
  my $fdFind = [sort @{fd($shallowDir) } ];
  #note Dumper [$gnuFind, $fileFindFast, $fileFind];
  is_deeply($fileFindFast, $gnuFind, "File::Find::Fast");
  is_deeply($fileFindFastIter, $gnuFind, "File::Find::Fast::fast_iter");
  is_deeply($fileFind, $gnuFind, "File::Find");
  is_deeply($pirFresh, $gnuFind, "Path::Iterator::Rule");
  is_deeply($pirReused, $gnuFind, "Path::Iterator::Rule2");
  is_deeply($fdFind, $gnuFind, "Fd-find");

  my $cmp = 
    cmpthese(-5, { 
    #cmpthese(1000, { 
        'gnuFind'          => sub { gnuFind($shallowDir) },
        'File::Find::Fast' => sub { fileFindFast($shallowDir) },
        'File::Find::fast_iter' => sub { fileFindFastIter($shallowDir) },
        'File::Find'       => sub { fileFind($shallowDir) },
        'Path::Iterator::Rule'  => sub { pirFresh($shallowDir) },
        'Path::Iterator::Rule2'  => sub { pirReused($shallowDir) },
        'Fd-find'          => sub { fd($shallowDir) },
    });

  for(my $i=0;$i<@$cmp;$i++){
    #note join("\t", @{ $$cmp[$i] });
    my @a = @{ $$cmp[$i] };
    my $row = "";
    for(my $j=0;$j<@a;$j++){
      # 22 characters to help hold our longest string Path::Iterator::Rule2
      $row .= sprintf("%22s ", $a[$j]);
    }
    diag $row;
  }

};

subtest 'Benchmark deep' => sub{
	my $deepDir = "$thisDir/deepfiles";
  my $directory_depth = 5;
  my $num_files = 5;
  create_deep_directory($deepDir, $directory_depth, $num_files);

  # initial check
  my $gnuFind = [sort @{ gnuFind($deepDir) } ];
  my $fileFindFast = [sort @{ fileFindFast($deepDir) } ];
  my $fileFindFastIter = [sort @{ fileFindFastIter($deepDir) } ];
  my $fileFind = [sort @{fileFind($deepDir) } ];
  my $pirFresh = [sort @{pirFresh($deepDir) } ];
  my $pirReused= [sort @{pirReused($deepDir) } ];
  my $fdFind = [sort @{fd($deepDir) } ];
  #note Dumper [$gnuFind, $fileFindFast, $fileFind];
  is_deeply($fileFindFast, $gnuFind, "File::Find::Fast");
  is_deeply($fileFindFastIter, $gnuFind, "File::Find::Fast::fast_iter");
  is_deeply($fileFind, $gnuFind, "File::Find");
  is_deeply($pirFresh, $gnuFind, "Path::Iterator::Rule");
  is_deeply($pirReused, $gnuFind, "Path::Iterator::Rule2");
  is_deeply($fdFind, $gnuFind, "Fd-find");

  my $cmp = 
    cmpthese(-5, { 
    #cmpthese(1000, { 
        'gnuFind'          => sub { gnuFind($deepDir) },
        'File::Find::Fast' => sub { fileFindFast($deepDir) },
        'File::Find::fast_iter' => sub { fileFindFastIter($deepDir) },
        'File::Find'       => sub { fileFind($deepDir) },
        'Path::Iterator::Rule'  => sub { pirFresh($deepDir) },
        'Path::Iterator::Rule2'  => sub { pirReused($deepDir) },
        'Fd-find'          => sub { fd($deepDir) },
    });

  for(my $i=0;$i<@$cmp;$i++){
    #note join("\t", @{ $$cmp[$i] });
    my @a = @{ $$cmp[$i] };
    my $row = "";
    for(my $j=0;$j<@a;$j++){
      # 22 characters to help hold our longest string Path::Iterator::Rule2
      $row .= sprintf("%22s ", $a[$j]);
    }
    diag $row;
  }

  rmtree($deepDir);
};

