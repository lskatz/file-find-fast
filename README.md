# File Find Fast

`File::Find::Fast` because `File::Find` is too slow for me.

# Quick start

```perl
use Data::Dumper qw/Dumper/;
use File::Find::Fast qw/find/;

my $files = find("some/directory");
print Dumper $files
```

# Functions

## find

Finds all files recursively in a directory.
From there, you can use `grep` or whatever your favorite function is to remove files.

