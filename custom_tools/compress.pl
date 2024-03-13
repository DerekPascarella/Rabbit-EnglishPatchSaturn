#!/usr/bin/perl
#
# compress.pl
#
# RLE encoder for .DAT files from the SEGA Saturn game "Rabbit".
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;

# Set input/output directories.
my $input_directory = "dat_files/decompressed_new/";
my $output_directory = "dat_files/compressed_new/";
my $original_directory = "dat_files/compressed_original/";

# Set duplicate byte threshold.
my $threshold = 4;

# Read the contents of the input directory into an array.
opendir(my $input_handler, $input_directory);
my @dat_files = grep { !/^\.\.?$/ } sort(readdir($input_handler));
closedir($input_handler);

# Iterate through each file.
foreach(@dat_files)
{
	# Store contents of uncompressed file and its size in bytes.
	my $file_bytes = &read_bytes($input_directory . "/" . $_);
	my $file_size = length($file_bytes) / 2;

	# Store original compressed file's size and RLE code.
	my $file_size_original = &read_bytes($original_directory . "/" . $_, 4);
	my $rle_code = &read_bytes_at_offset($original_directory . "/" . $_, 1, 4);

	# Status message.
	print "$_ - RLE code: $rle_code\n";

	# Set initial seek position.
	my $position = 0;

	# Initialize compressed file variable, starting with four-byte file size and RLE code.
	my $compressed_file_bytes = $file_size_original . $rle_code;

	# Seek through file until the end.
	while($position < $file_size * 2)
	{
		# Assess for repeating bytes according to threshold if doing so doesn't exceed end of file.
		if($position + (($threshold - 1) * 2) < $file_size * 2)
		{
			# Store current byte.
			my $byte = substr($file_bytes, $position, 2);
			
			# Store copy of position for duplicate byte seeking.
			my $dupe_seek_position = $position;

			# Default "duplicate found" flag to true.
			my $dupe_found = 1;

			# Seek through file according to threshold.
			while($dupe_seek_position < $position + ($threshold * 2))
			{
				# Current byte does not equal first, set flag to false.
				if(substr($file_bytes, $dupe_seek_position, 2) ne $byte)
				{
					$dupe_found = 0;

					# Break loop.
					last;
				}

				# Increase duplicate seek position by one byte.
				$dupe_seek_position += 2;
			}

			# Sequential duplicate bytes were found in accordance with threshold.
			if($dupe_found)
			{
				# Initialize repeating byte counter to zero.
				my $repeat_count = 0;

				# Initialize empty repeating byte array variable.
				my $repeating_bytes = "";

				# Store repeating byte to assess.
				my $repeat_byte = $byte;

				# Append RLE code and repeating byte to output file.
				$compressed_file_bytes .= $rle_code . $repeat_byte;

				# Seek through file until the end to find sequential repeating bytes.
				while($position < $file_size * 2 && $repeat_count < 255)
				{
					# Store current byte.
					my $byte = substr($file_bytes, $position, 2);

					# Current byte equals repeat byte.
					if($byte eq $repeat_byte)
					{
						# Append current bytes to repeating byte array.
						$repeating_bytes .= $byte;
						
						# Increase repeating byte counter by one.
						$repeat_count ++;

						# Increase seek position by one byte.
						$position += 2;
					}
					# Otherwise, break loop.
					else
					{
						last;
					}
				}

				# Append byte repeat count to output file.
				$compressed_file_bytes .= &decimal_to_hex($repeat_count, 1);
			}
			# Duplicate bytes were not found, treat as individual.
			else
			{
				# Store current byte.
				my $byte = substr($file_bytes, $position, 2);

				# Append byte to output file.
				$compressed_file_bytes .= $byte;

				# Increase seek position by one byte.
				$position += 2;
			}
		}
		# Otherwise, treat as individual.
		else
		{
			# Store current byte.
			my $byte = substr($file_bytes, $position, 2);

			# Append byte to output file.
			$compressed_file_bytes .= $byte;

			# Increase seek position by one byte.
			$position += 2;
		}
	}

	# Update new file size before applying padding.
	substr($compressed_file_bytes, 0, 8) = &decimal_to_hex((length($compressed_file_bytes) / 2) - 5, 4);

	# Pad data with null bytes to fill original file size of 196608 bytes.
	for(length($compressed_file_bytes) / 2 .. 196607)
	{
		$compressed_file_bytes .= "00";
	}

	# Write compressed file to output directory.
	&write_bytes($output_directory . "/" . $_, $compressed_file_bytes);

	&write_bytes("/mnt/z/saturn/__projects/rabbit/patched_extracted/" . $_, $compressed_file_bytes);
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

# Subroutine to read a specified number of bytes, starting at a specific offset (in decimal format), of
# a specified file, returning hexadecimal representation of data.
#
# 1st parameter - Full path of file to read.
# 2nd parameter - Number of bytes to read.
# 3rd parameter - Offset at which to read.
sub read_bytes_at_offset
{
	my $input_file = $_[0];
	my $byte_count = $_[1];
	my $read_offset = $_[2];

	if((stat $input_file)[7] < $read_offset + $byte_count)
	{
		die "Offset for read_bytes_at_offset is outside of valid range.\n";
	}

	open my $filehandle, '<:raw', $input_file or die $!;
	seek $filehandle, $read_offset, 0;
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

# Subroutine to return hexadecimal representation of a decimal number.
#
# 1st parameter - Decimal number.
# 2nd parameter - Number of bytes with which to represent hexadecimal number (omit parameter for no
#                 padding).
sub decimal_to_hex
{
	if($_[1] eq "")
	{
		$_[1] = 0;
	}

	return sprintf("%0" . $_[1] * 2 . "X", $_[0]);
}