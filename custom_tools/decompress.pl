#!/usr/bin/perl
#
# decompress.pl
#
# RLE decoder for .DAT files from the SEGA Saturn game "Rabbit".
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;

# Set input/output directories.
my $input_directory = "dat_files/compressed_original/";
my $output_directory = "dat_files/decompressed_original/";

# Read the contents of the input directory into an array.
opendir(my $input_handler, $input_directory);
my @dat_files = grep { !/^\.\.?$/ } sort(readdir($input_handler));
closedir($input_handler);

# Iterate through each file.
foreach(@dat_files)
{
	# Store contents of compressed file, as well as its total size and RLE code.
	my $file_bytes = &read_bytes($input_directory . "/" . $_);
	my $file_size = hex(substr($file_bytes, 0, 8)) + 5;
	my $rle_code = substr($file_bytes, 8, 2);

	# Status message.
	print "$_ - $file_size bytes - RLE code: $rle_code\n";

	# Set initial seek position.
	my $position = 10;

	# Initialize empty decompressed file variable.
	my $decompressed_file_bytes = "";

	# Seek through file until the end.
	while($position < $file_size * 2)
	{
		# Store current byte.
		my $byte = substr($file_bytes, $position, 2);

		# Byte represents RLE code, do run.
		if($byte eq $rle_code)
		{
			# Store value to run and its run-length.
			$position += 2;
			my $value = substr($file_bytes, $position, 2);
			$position += 2;
			my $length = hex(substr($file_bytes, $position, 2));

			# Append bytes to output file.
			for(my $i = 0; $i < $length; $i ++)
			{
				$decompressed_file_bytes .= $value;
			}
		}
		# Plain byte.
		else
		{
			# Append byte to output file.
			$decompressed_file_bytes .= $byte;
		}

		# Increase seek position ahead by one byte.
		$position += 2;
	}

	# Write decompressed file to output directory.
	&write_bytes($output_directory . "/" . $_, $decompressed_file_bytes);
}

# Subroutine to read a specified number of bytes (starting at the beginning) of a specified file,
# returning hexadecimal representation of data.
#
# 1st parameter - Full path of file to read.
# 2nd parameter - Number of bytes to read (omit parameter to read entire file).
sub read_bytes
{
	my $input_file = $_[0];
	my $byte_count = $_[1];

	if($byte_count eq "")
	{
		$byte_count = (stat $input_file)[7];
	}

	open my $filehandle, '<:raw', $input_file or die $!;
	read $filehandle, my $bytes, $byte_count;
	close $filehandle;
	
	return unpack 'H*', $bytes;
}

# Subroutine to write a sequence of hexadecimal values to a specified file.
#
# 1st parameter - Full path of file to write.
# 2nd parameter - Hexadecimal representation of data to be written to file.
sub write_bytes
{
	my $output_file = $_[0];
	(my $hex_data = $_[1]) =~ s/\s+//g;
	my @hex_data_array = split(//, $hex_data);

	open my $filehandle, '>:raw', $output_file or die $!;
	binmode $filehandle;

	for(my $i = 0; $i < scalar(@hex_data_array); $i += 2)
	{
		my($high, $low) = @hex_data_array[$i, $i + 1];
		print $filehandle pack "H*", $high . $low;
	}

	close $filehandle;
}