#!/usr/bin/env perl

use JSON;
use strict;
use warnings;
use HTTP::Tiny;
use Getopt::Long;

#Automatically flushes the output streams
$| = 1;

#Help function (explain options, usage, etc. and exit)
sub help
{
	print <<HELP;

$0 - Obtains data on the number of cases of corona virus in Brazil.

Usage: $0 [options]

Options:
    -h, --help          Show this help message and exit.
    -o, --output        A file to save the data to (just show it by default).
    -r, --region        The region from which you want to obtain data.
    -s, --state         The state from which you want to obtain data.

HELP
	exit(0);
}

#Regions
my @regions = qw(Sudeste Nordeste Norte Centro-Oeste Sul);

#Variables to get options using Getopt::Long
my $output;
my $region;
my $state;

#Process options from command line
GetOptions(
	"o|output=s" => \$output,
	"r|region=s" => \$region,
	"s|state=s"  => \$state,
	"g|help"	 => \&help
);

#Let the user select a region if it was not specified on command line
while (!defined($region))
{
	print "Select a region from which you want to obtain data:\n";
	print "$_ - $regions[$_]\n" for 0 .. @regions - 1;
	print "Region: ";
	my $index = int(<STDIN>);
	if ($index >= 0 && $index < @regions)
	{
		$region = $regions[$index];
	}
	else
	{
		print "Invalid region. Try again\n";
	}
}

#Validate the informed region
die "$0: Invalid region" unless grep(/$region/, @regions);

#Perform a HTTP GET request
my $http = HTTP::Tiny->new();
my $resp = $http->get('https://xx9p7hp1p7.execute-api.us-east-1.amazonaws.com/prod/PortalRegiaoUf');
my $data = $resp->{success} ? $resp->{content} : die "Can't get data";

#Decode the JSON data
my $struct = decode_json($data);

#Select region
my $sel_region = $struct->{$region};
my @states = keys %{$sel_region};
#Let the user select a state if it was not specified on command line
while (!defined($state))
{
	print "Select a state from which you want to obtain data:\n";
	print "$_ - $states[$_]\n" for 0 .. @states - 1;
	print "State: ";
	my $index = int(<STDIN>);
	if ($index >= 0 && $index < @states)
	{
		$state = $states[$index];
		#Print a line to separe the previous output from the data
		print "\n" . "="x80 . "\n\n";
	}
	else
	{
		print "Invalid state. Try again\n";
	}
}

#Validates the informed state
die "$0: Invalid state" unless grep(/$state/, @states);

#Select state
my $sel_state = $sel_region->{$state};

#Lookup by days
my $days = $sel_state->{dias};

my %sorting;

#Add each day into a hash {date} = cases (apparently, not always sorted)
for my $i (0 .. @{$days})
{
	if ($days->[$i]->{casosAcumulado})
	{
		$sorting{$days->[$i]->{_id}} = $days->[$i]->{casosAcumulado};
	}
}

#Sort the number of cases by date
sub date_cmp
{
	my ($a, $b) = @_;
	my ($da, $ma) = split /\//, $a;
	my ($db, $mb) = split /\//, $b;
	if ($ma > $mb)
	{
		return 1
	}
	elsif ($mb > $ma)
	{
		return -1
	}
	if ($da > $db)
	{
		return 1
	}
	elsif ($db > $da)
	{
		return -1
	}
	return 0
}

#Get the dates sorted
my @sorted = sort { date_cmp $a, $b } keys %sorting;

#If a output file is informed, the data will be printed to it
if ($output)
{
	open(STDOUT, ">$output") || die "$0: Can't open $output for writting: $!"
}

#Index the number of cases (starting at 1)
my $index = 1;

#Show column names
print STDOUT "Índice\tData\tCasos\n";

#Show/save the data
for my $date (@sorted)
{
	print STDOUT "$index\t$date\t$sorting{$date}\n";
	$index ++;
}

#Close output file
close STDOUT;
