#!/usr/bin/python3
# May 26, 2021 J.A. Waters
# Using the "file" command to check for obfuscated data, and testing basic information encryption / decryption
# This program is provided under the MIT License

# Imports
import base64, binascii, os, pkg_resources, subprocess, sys
from argparse import ArgumentParser
from cryptography.fernet import Fernet

# Set an object with the required packages
required = {'python-magic'}

if not os.name == "posix":
	required = {'python-magic', 'python-magic-bin'}

# Get the currently installed packages
installed = {pkg.key for pkg in pkg_resources.working_set}
# Set the date for missing packages
missing = required - installed

# If there are any items missing, install those modules with pip
if missing:
	# Use the system python executable to run pip rather than using the pip module directly imported
	python = sys.executable
	subprocess.check_call([python, '-m', 'pip', 'install', *missing], stdout=subprocess.DEVNULL)

import magic

# Globals
# Default crypto key; shouldn't be used or reused for production data
useKey = b'a-1oGqvIJzA5ZPriEvuJrI1rpkN71dfJe4oSQ9ay4Dk='

# If needed on a Windows OS, the following release was compiled for Windows
# https://github.com/nscaife/file-windows/releases/download/20170108/file-windows-20170108.zip

# Entry point
if __name__ == '__main__':
	# General parsing for options / arguments and also for providing help details
	helpDesc = "Creating, removing, or detecting file obfuscation with encryption and padding"
	parser = ArgumentParser(description = helpDesc)

	# Arguments for choosing an operation, and also allow for generating new keys or spoofing file types
	parser.add_argument("-c", "--choice", choices = [ "create", "remove", "detect" ], default = "detect", help = "add or remove padding and encryption to 'hide' / obfuscate a file or attempt recovery; attempt detection of file obfuscation or corruption")
	parser.add_argument("-i", "--infile", default = "no_file_chosen", help = "set the file input to operate on")
	parser.add_argument("-o", "--outfile", default = "no_file_chosen", help = "set the file name to output")
	parser.add_argument("-g", "--genkey", action = "store_true", default = False, help = "generate a new cryptographic key for encrypting files")
	parser.add_argument("-k", "--keyfile", default = "no_file_chosen", help = "specify the cryptographic key to use or save for encrypting files")
	parser.add_argument("-s", "--spoof", action = "store_true", default = False, help = "inject another filetype's hex into an existing file")
	parser.add_argument("-f", "--fakedata", default = "49492A00100000004352", help = "specify the hex value to add to a file; default is Canon RAW")

	opts = parser.parse_args()
	
	# Generates key file to be used for encrypting / decrypting data
	if opts.genkey:
		key = Fernet.generate_key()

		# By default, use 'keyfile' as the filename to output
		keyname = "keyfile"
		if not opts.keyfile == "no_file_chosen":
			keyname = opts.keyfile
		
		# Write the generated key
		with open(keyname, "wb") as key_file:
			key_file.write(key)
		
		exit("Key generated at './" + keyname + "'")

	# If a key was specified, open the file and store it as a byte literal for later use
	if not opts.keyfile == "no_file_chosen":
		keyload = open(opts.keyfile, "rb")
		usekey = keyload.read()
		
	# Require at least that an input file is chosen, otherwise just exit
	if opts.infile == "no_file_chosen":
		exit("Please specify an input file.")
		
	if opts.spoof:
		# Rename the outfile to show that it was spoofed; use at least one period to do this split
		spoofFile = os.path.basename(opts.infile)
		spoofParts = spoofFile.split(".")
		# Add the word 'spoof' and then the period back in there somewhere
		spoofFile = spoofParts[0] + "_spoof." + spoofParts[1]
		
		# Open the data from the input file
		data = open(opts.infile, "rb")
		# Create the byte literal of that data
		byteString = data.read()
		# Take the provided or default file signature and make sure its in a byte literal format
		fakeBytes = bytes(opts.fakedata, encoding = "utf-8")
		# Prepend the fake file signature data to the front of the file; use hexlify to allow for operating on the byte literal as a string
		hexData = fakeBytes + binascii.hexlify(byteString)
		# Change everything back into a byte literal
		newBytes = binascii.unhexlify(hexData)
		
		# Write the resulting file
		with open(spoofFile, "wb") as out_file:
			out_file.write(newBytes)
			
		exit("Data added to the file " + opts.infile + "; saved as " + spoofFile)

	# Parse additional operation choices provided by the user
	if opts.choice == "detect":
		#res = subprocess.check_output(["file", opts.infile], universal_newlines = True)
		res = magic.from_file(opts.infile)
		# Output the file type as shown by the file command
		print(res)
		
	# Simple method of taking any file as binary and converting to an encrypted base64 string
	if opts.choice == "create":
		# If a file name wasn't given, rename the outfile to show that it contains encrypted data
		if opts.outfile == "no_file_chosen":
			newName = os.path.basename(opts.infile)
			newParts = newName.split(".")
			opts.outfile = newParts[0] + "_enc." + newParts[1]
	
		data = open(opts.infile, "rb")
		byteString = data.read()
		b64String = base64.b64encode(byteString)
		
		# Add the original filename for later decrypting
		b64String = b64String.decode("ascii") + ";" + os.path.basename(opts.infile)
		print(b64String)
		
		# Encrypt the base64 string with the Fernet recipe
		fernet = Fernet(useKey)
		encString = fernet.encrypt(b64String.encode())
		
		with open(opts.outfile, "wb") as out_file:
			out_file.write(encString)
			
	# Converting from an encrypted base64 string and outputing with the original file name
	if opts.choice == "remove":
		data = open(opts.infile, "rb")
		byteString = data.read()
		
		# Decrypt the file data with the Fernet recipe
		fernet = Fernet(useKey)
		encString = fernet.decrypt(byteString).decode("ascii")
		
		# Split the result at the semicolon; where the original filename was added
		resString = encString.split(";")
		
		# Decode from base64
		unencString = base64.b64decode(resString[0])
		
		# Write the new file with its unencrypted text
		with open(resString[1], "wb") as out_file:
			out_file.write(unencString)
