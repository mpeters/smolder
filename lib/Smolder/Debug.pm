package Smolder::Debug;
use Carp qw(longmess);
use Data::Dumper;
use strict;
use warnings;
use base qw(Exporter);

our @EXPORT = qw(
  dd
  dp
  dps
  dpo
  dpso
);

sub dump_one_line {
    my ($value) = @_;

    return Data::Dumper->new([$value])->Indent(0)->Sortkeys(1)->Quotekeys(0)->Terse(1)->Dump();
}

sub _dump_value_with_caller {
    my ($value) = @_;

    my $dump = Data::Dumper->new([$value])->Indent(1)->Sortkeys(1)->Quotekeys(0)->Terse(1)->Dump();
    my @caller = caller(1);
    return sprintf("[dp at %s line %d.] %s\n", $caller[1], $caller[2], $dump);
}

sub dd {
    die _dump_value_with_caller(@_);
}

sub dp {
    print STDERR _dump_value_with_caller(@_);
}

sub dps {
    print STDERR longmess(_dump_value_with_caller(@_));
}

sub dpo {
    print _dump_value_with_caller(@_);
}

sub dpso {
    print longmess(_dump_value_with_caller(@_));
}

1;
