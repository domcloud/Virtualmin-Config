package Virtualmin::Config::DomCloud;
use strict;
use warnings;
use 5.010_001;

# A list of plugins for configuring a LEMP stack

sub new {
  my ($class, %args) = @_;
  my $self = {};

  return bless $self, $class;
}

sub plugins {
  # DOM Cloud only use subset of features
  return [
    "Webmin",   "Nginx",    "Bind",    "Postfix",    "MySQL",
    "Firewall", "Quotas",    "Status", "Upgrade",   "Virtualmin",
  ];
}

1;
