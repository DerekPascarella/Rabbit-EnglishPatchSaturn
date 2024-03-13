#!/usr/bin/perl
#
# rebuild_disc_image.pl
# Rebuild disc image for the game "Rabbit" using CD-REPLACE
# (https://www.romhacking.net/utilities/852/).
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;

# Define paths.
my $disc_image_extracted_folder = "Z:\\saturn\\__projects\\rabbit\\patched_extracted\\";
my $disc_image = "Z:\\saturn\\__projects\\rabbit\\patched_disc_image\\Rabbit (Japan) (Track 01).bin";

# Store list of files to replace.
opendir(my $dh, $disc_image_extracted_folder);
my @file_list = grep { !/^\.\.?$/ } readdir($dh);
closedir($dh);

# Iterate through each element of file list array.
foreach(@file_list)
{
	# Construct full path to replacement file.
	my $file_path = $disc_image_extracted_folder . "\\" . $_;

	# Invoke CD-REPLACE.
	system "cd-replace.exe \"$disc_image\" $_ \"$file_path\"";
}