# Bluefite
Tool for connecting to different devices via bluetooth

# Requirements
You need to be able to run the following commands:

hcitool

hciconfig

l2ping

sdptool

bluesnarfer

# Usage
Download latest release from the releases page or compile one yourself.
Rename the file as you want (for example, bluefite.bin).
Run `chmod +x bluefite.bin `
and start with `sudo ./bluefite.bin `

If you want to be able to run the tool with one command you can use `sudo ln -s ./bluefite.bin /usr/bin/bluefite `

# Compiling
Requires DMD/GDC/LDC
Compilation is simple - run `dmd app.d`
