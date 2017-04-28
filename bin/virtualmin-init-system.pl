#!/usr/bin/env perl
use strict;
use warnings;
use 5.010_001;
use Getopt::Long;
use Pod::Usage;
use Virtualmin::Config;

sub main {
  my ($argv) = @_;
  my %opt;
  my (@include, @exclude);
  GetOptions(
    \%opt, 'help|h', 'bundle|b=s', 'log|l=s',
    'include|i=s{1,}' => \@include,
    'exclude|x=s{1,}' => \@exclude,
  );
  pod2usage(0) if $opt{help};
  unless ($opt{bundle} || @include) {
    pod2usage(0);
  }

  my $bundle = Virtualmin::Config->new(
    bundle  => $opt{bundle},
    log     => $opt{log},
    include => \@include,
    exclude => \@exclude,
  );

  $bundle->run();

  return 0;
}

exit main(\@ARGV);

=pod

=head1 NAME

init-system

=head1 SYNOPSIS

virtualmin init-system [options]

  Options:
    --help      Print this summaery of options and exit
    --bundle    A bundle of plugins to execute
    --log       Path to a file for logging actions
    --include   One or more extra plugins to include
    --exclude   One or more plugins to exclude

=head1 OPTIONS

=over

=item --bundle

A set of confguration options, to initialize the system for use as a Virtualmin
system. Default plugin bundle is "LAMP", which configures Apache, as well as
a variety of other components. "LEMP" replaces Apache with nginx.

=item --include

Include one or more additional plugins. Works with or without a bundle
specified. Multiple plugins can be provided with this option, separated by
spaces. If no bundle is specified, only the included plugins, and dependencies
will be installed.

=item --exclude

Exclude one or more plugins from either the default bundle, if no  bundle is
specified, or from the bundle specified.

=back

=head1 EXIT CODES

Returns 0 on success, 1 on failure.

=head1 LICENSE AND COPYRIGHT

Licensed under the GPLv3. Copyright 2017, Joe Cooper <joe@virtualmin.com>

=cut