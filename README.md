# Generate and run ![x64](https://en.wikipedia.org/wiki/X86-64)  ![Advanced Vector Extensions](https://en.wikipedia.org/wiki/AVX-512) assembler programs from Perl

![Test](https://github.com/philiprbrenan/Nasmx86/workflows/Test/badge.svg)

This Perl ![module](https://en.wikipedia.org/wiki/Modular_programming) generates and runs ![x64](https://en.wikipedia.org/wiki/X86-64) ![Advanced Vector Extensions](https://en.wikipedia.org/wiki/AVX-512) assembler programs. It contains
methods to perform useful macro functions such as dumping x/y/zmm* registers to
facilitate the debugging of the generated programs.

The ![GitHub Action](https://docs.github.com/en/free-pro-team@latest/actions/quickstart) in this repo shows how to ![install](https://en.wikipedia.org/wiki/Installation_(computer_programs)) ![nasm](https://github.com/netwide-assembler/nasm) and the ![Intel Software Development Emulator](https://software.intel.com/content/www/us/en/develop/articles/intel-software-development-emulator.html) used
to assemble and then run the programs egnerated by this ![module](https://en.wikipedia.org/wiki/Modular_programming). 
Test cases can be seen at the end of **lib/Nasm/X86.pm**
