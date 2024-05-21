use strict;
use warnings;

use File::Find;
use Getopt::Long;
use Pod::Usage;
use Digest::SHA qw(sha256_hex);

my $path = ".";
my @ignore_exts;
my $ignore_hidden = 1;
my $quiet = '';
my $help = '';

GetOptions("path=s" => \$path, 
	"ignore-ext=s@" => \@ignore_exts, 
	"ignore-hidden" => \$ignore_hidden,
	"quiet" => \$quiet,
	"help" => \$help)
	or pod2usage(2);

pod2usage( -verbose => 1) if $help;

my %first_files;
my %second_files;

sub file_hash {
    my ($file_path) = @_;

    my $size = -s $file_path;

    # TODO: I think this block is never used
    if (-d $file_path) {
	return "dir";
    }

    # Getting file contents
    open(my $fh, "<:raw", "$file_path") or die "Failed to open file: $file_path\n";

    # If it's empty, just hash an empty string
    # TODO: I don't think this is necessary though
    if (-s $fh == 0) {
	return sha256_hex('');
    }

    # Getting our hash value
    my $sha = Digest::SHA->new(256);
    $sha->addfile($fh);
    my $hash = $sha->hexdigest;

    # No memory leaks!!!!
    close($fh);
    return $hash
}

sub process_file {
    my ($files) = @_;

    # Setting a placeholder for directories
    if (-d $File::Find::name) {
	$files->{$File::Find::name} = 'dir';
	return;
    }

    if (!$quiet) {
	print "Found: $File::Find::name\n";
    }
    
    $files->{$File::Find::name} = file_hash($File::Find::name);
}


print "Running snapshot 1...\n";

# Enumerating our files
find({ wanted => sub {
    process_file(\%first_files);
     }, no_chdir => 1}, "$path");

print "\nDone. Press enter to run a second snapshot.\n";
# Getting junk data from stdin
<>;

find({ wanted => sub {
    process_file(\%second_files);
     }, no_chdir => 1}, "$path");

# Checking for deletions
for (keys %first_files) {
    if (!$second_files{$_}) {
	print "File deleted: $_\n";
    }
}

# Checking for additions
for (keys %second_files) {
    if (!$first_files{$_}) {
	print "File added: $_\n";
    }
}

# Checking for differences
for (keys %second_files) {
    # TODO: Ignoring deletions, could probably move this up
    if (!$first_files{$_}) {
	next;
    }

    if ($second_files{$_} ne $first_files{$_}) {
	print "File content modified: $_\n";
    }
}

__END__

=head1 NAME

fshot - Filesystem Snapshotter

=head1 SYNOPSIS

fshot [options]

=head1 OPTIONS

=over 4

=item B<--help>

Prints this menu

=item B<--path>

Path to snapshot

=item B<--ignore-ext>

An extension to ignore (can provide multiple)

=item B<--ignore-hidden>

Ignores hidden files

=item B<--quiet>

Does not output unnecessary info

=back

=head1 DESCRIPTION

B<fshot> will snapshot a filesystem twice and compare the differences

=cut
