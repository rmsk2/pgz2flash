
# About
This tool can be used to transform (most) Foenix F256 PGZ executable files to Kernel User Programs (KUPs), which can be run from
onboard or cartridge flash memory.

# Usage

`pgz2flash` is a CLI program written in Go which offers the following command line options

```
Usage of pgz2flash:
  -desc string
    	Description shown in lsf
  -name string
    	Name of program in flash and shown by lsf
  -onboard int
    	Optional: Create 8K blocks for FoenixMgr. Use param as number of start block. (default -1)
  -out string
    	Output file name
  -pgz string
    	Path to pgz
  -version
    	Show version information
```

Use `-pgz` to specify the file in which the PGZ program which you want to convert is stored. The option `-name` can be used to determine the
name by which the KUP is listed via `lsf` in DOS. This name must also be used to start the KUP. I.e. when the string `test` is used
as the value of the `-name` option the program must be started as `/test`. The value of `-desc` can be used to define the program description
shown by `lsf`. `-out` sets the name of the file in which the conversion result is stored. Before you can run the resulting KUP you have to write
it either to onboard flash via `FoenixMgr` or to a flash cartridge via `fcart`. The created KUPs are agnostic with respect to their storage 
location in flash memory. The `-version` option can be used to retrieve version information about your copy of `pgz2flash`. If you intend to write
the transformation result to onboard flash via `FoenixMgr` you will need separate 8K flash blocks instead of a single cartridge image which is 
required by `fcart`. Use the option `-onboard` to create the KUP as a collection of 8K blocks which can be processed by `FoenixMgr`. The value 
of the option `-out` is used to determine the names of the individual blocks and the csv file to control `FoenixMgr`.

When you run `pgz2flash`, information about the structure of the PGZ file which is to be converted is shown. Additionally information about the 
copy operations (or copy instructions) performed by the loader program are shown. As an example here the data printed when transforming the 
helicopter demo which is part of @sduensin's LLVM-MOS package (and contained in this repo for testing purposes) using the command 
`./pgz2flash -pgz helicopter.pgz -name helic -desc "LLVM Helicopter demo" -out helic.bin`

```
Start address: $000200

PGZ segments:
=============
01. Load address $000200, Length $00389E
02. Load address $010000, Length $002800
03. Load address $012800, Length $002800
04. Load address $015000, Length $002800
05. Load address $017800, Length $002800
06. Load address $01A000, Length $000080

Generated copy instructions
===========================
---------- Address: $000200 length: $00389E
Copy $1D0B bytes from $00:82f5 to $00:6200
Copy $00F5 bytes from $01:8000 to $00:7F0B
Copy $1A9E bytes from $01:80f5 to $01:6000
---------- Address: $010000 length: $002800
Copy $046D bytes from $01:9b93 to $08:6000
Copy $1B93 bytes from $02:8000 to $08:646D
Copy $046D bytes from $02:9b93 to $09:6000
Copy $0393 bytes from $03:8000 to $09:646D
---------- Address: $012800 length: $002800
Copy $1800 bytes from $03:8393 to $09:6800
Copy $046D bytes from $03:9b93 to $0A:6000
Copy $0B93 bytes from $04:8000 to $0A:646D
---------- Address: $015000 length: $002800
Copy $1000 bytes from $04:8b93 to $0A:7000
Copy $046D bytes from $04:9b93 to $0B:6000
Copy $1393 bytes from $05:8000 to $0B:646D
---------- Address: $017800 length: $002800
Copy $0800 bytes from $05:9393 to $0B:7800
Copy $046D bytes from $05:9b93 to $0C:6000
Copy $1B93 bytes from $06:8000 to $0C:646D
---------- Address: $01a000 length: $000080
Copy $0080 bytes from $06:9b93 to $0D:6000
---------- Stop instruction
Copy $0000 bytes from $00:0200 to $00:0000

Overall 17 of 64 copy instructions were used
```

# How does this work?

The Go program configures an assembly loader which copies the data contained in the PGZ file from flash to the specified load addresses just as `pexec` would do with data read
from a file. Additionally the Go program removes the length and address fields of the PGZ and prepends the configured loader to the concatenation of the pure segment data. What
do I mean by configured? The Go program adds data to the loader binary (which can be found in the `loader.go` file) which defines copy operations to be performed upon program
start. When the loader is started by the Kernel it interprets this data in order to perform the neccessary copy operations. The address space of the F256 machines is segmented 
into 8K blocks and this makes copying data not as straight forward as one would like. Due to this fact copying a segement often requires more than one copy operation.

# Test results

 I have tested the following programs which I could successfully transform into a fully working KUP:

- Kooyan (October 2024 game jam)
- My own 2048 game
- Trick or treat (October 2024 game jam)
- The LLVM-MOS helicopter demo (compiled by myself a while ago)
- fnxsnake (October 2024 game jam)
- My own snake game (October 2024 game jam)
- BachHero (October 2024 game jam)
- The Hallow (October 2024 game jam)

I encountered one case (`spooky.pgz` of the October 2024 game jam) where the resulting KUP would not run correctly. At the moment I assume that this has nothing to do with the
transformation process but is caused by missing initializations (for instance done by SuperBASIC or `pexec`) on which the software unknowingly depends but which are not happening 
when being started as a KUP via the `loader`.

For one October 2024 Game Jam contestant `warlock.pgz` the transformation worked but I was unable to test the resulting flash image as it did not fit on a flash cartridge and in fact
it did also not fit into the remaining onboard flash.

# Limitations

If your program depends on files which have to be read from a drive for initialization purposes then these files will not become part of the flash image. I expect such programs
to work just fine as a KUP but they still need their files stored on disk in order to run.

# Building the program

You will need a Go compiler, a Python interpreter, `64tass` and GNU make to build this software. Building is done in three steps. At first the assembly loader is compiled. 
The result  is the loader binary and a label file. Then the loader binary is transformed into Go source code and stored in the file `loader.go`. Finally `pgz2flash` is built 
using `go build`. This whole process is automated in the provided `makefile`. Simply use `make` to build the binary. As usual the target `clean` can be used to delete
all intermediary files. When building under Windows you have to call make as follows `make WIN=1`.

If the assembly source code is modified you have to make sure that the following label values do match the corresponding constants in the Go program. You can use the file
`labels.txt`, which is generated by `64tass`, for verification.

| Label | Go constant |
|-|-|
| `ADDR_DESCRIPTION` | `DescriptionAddress` |
| `ADDR_NUM_BLOCKS` | `NumBlocksAddress` |
| `ADDR_INSTRUCTIONS`| `CopyInstructions` |
| `LOAD_ADDRESS` | `LoadAddress` |
| `SOURCE_ADDRESS` | `SourceWindow` |
| `TARGET_ADDRESS` | `TargetWindow` |

Additional modifications have to be performed when the maximum number of copy instructions is to be increased. You have to make room for them by changing the `.fill` directive
at `ADDR_INSTRUCTIONS` and after that you can adapt `MaxCopyInstructions` on the Go side. Similar preparations have to be made when increasing the space for the program name
and the description which are stored at `ADDR_DESCRIPTION`. When you use the target `binaries` you can build binaries for the platforms listed below.

# Prebuilt Binaries

You will find binaries for the following OSs and architectures in the Releases section of this repo.

|OS | Architecture | Binary name |
|-|-|-|
|Windows| Intel/Amd64 | `pgz2flash_win_amd64.exe`|
|macOS| Intel/Amd64 | `pgz2flash_mac_amd64`|
|macOS| M1/M2/M3/M4/Arm64 | `pgz2flash_mac_arm64`|
|Linux| Intel/Amd64 | `pgz2flash_linux_amd64`|
|Linux| 64Bit Raspi/Arm64 | `pgz2flash_linux_arm64`|

Caveats: Be warned that I can not test all these platforms with each release. I also have made the experience once that a go program compiled under some Linux distribution would not run
on another distribution. 

## Using the binaries on macOS

When you download the executables via the Releases section macOS will refuse to run them. You have to issue the following commands in order to be able to use them. First you have to make 
sure the file is executable by typing `chmod u+x pgz2flash_mac_arm64` or `chmod u+x pgz2flash_mac_amd64` after that you have to remove the quarantine attribute from the
files via `xattr -d com.apple.quarantine pgz2flash_mac_arm64` or `xattr -d com.apple.quarantine pgz2flash_mac_amd64`. This could probably be prevented if I would sign the binaries, but
to be honest, as I am not usually publishing software on macOS I won't pay Apple's developer club membership fee.

## Using the binaries under Windows

When I started the downloaded binary under Windows, the OS wanted to send the program to Microsoft for scanning. I declined that and after that the program would run.