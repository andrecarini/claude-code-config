#!/usr/bin/perl
# Merge repo settings.json into an existing ~/.claude/settings.json.
# Preserves the existing permissions block; updates everything else from repo defaults.
#
# Usage: perl merge-settings.pl <existing> <defaults>
# Prints merged JSON to stdout.
use strict;
use warnings;
use JSON::PP;

die "Usage: $0 <existing.json> <defaults.json>\n" unless @ARGV == 2;

my $codec = JSON::PP->new->pretty->canonical;

sub read_json {
    open my $fh, '<', $_[0] or die "Cannot open $_[0]: $!\n";
    local $/;
    return decode_json(<$fh>);
}

my $existing = read_json($ARGV[0]);
my $defaults = read_json($ARGV[1]);

# Save existing permissions
my $permissions = $existing->{permissions};

# Start from defaults, overlay existing permissions
my $merged = { %$defaults };
$merged->{permissions} = $permissions if $permissions;

print $codec->encode($merged);
