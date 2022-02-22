# File Find Fast

`File::Find::Fast` because `File::Find` is too slow for me.

# Quick start

```perl
use Data::Dumper qw/Dumper/;
use File::Find::Fast qw/find/;

my $files = find("some/directory");
print Dumper $files
```
