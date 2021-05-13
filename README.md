# Dfinity Manager

Download the script in the folder where you have the `nns-ifaces-0.8.0` folder.

`wget https://raw.githubusercontent.com/applepiesoft/DfinityManager/main/dman.rb`

or if you don't have wget

`https://raw.githubusercontent.com/applepiesoft/DfinityManager/main/dman.rb`

Usage:

`ruby dman.rb <LEGACY-ADDRESS>`

Make sure to use the LEGACY ADDRESS, not the public key, seed, or private key.

As a reminder, to find your legacy address, run:

`echo $seed | keysmith legacy-address -f -`
