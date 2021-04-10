#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/ -I. -I/home/phil/perl/cpan/AsmC/lib/
#-------------------------------------------------------------------------------
# Generate Nasm X86 code from Perl.
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2021
#-------------------------------------------------------------------------------
# podDocumentation
# Indent opcodes by call depth, - replace push @text with a method call
package Nasm::X86;
our $VERSION = "202104010";
use warnings FATAL => qw(all);
use strict;
use Carp qw(confess cluck);
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use Asm::C qw(:all);
use feature qw(say current_sub);

my $debug = -e q(/home/phil/);                                                  # Developing
my $sde   = q(/var/isde/sde64);                                                 # Intel emulator
   $sde   = q(sde/sde64) unless $debug;

binModeAllUtf8;

my %rodata;                                                                     # Read only data already written
my %rodatas;                                                                    # Read only string already written
my @rodata;                                                                     # Read only data
my @data;                                                                       # Data
my @bss;                                                                        # Block started by symbol
my @text;                                                                       # Code

my $sysout = 1;                                                                 # File descriptor for output

BEGIN{
  my %r = (    map {$_=>'8'}    qw(al bl cl dl r8b r9b r10b r11b r12b r13b r14b r15b sil dil spl bpl ah bh ch dh));
     %r = (%r, map {$_=>'s'}    qw(cs ds es fs gs ss));
     %r = (%r, map {$_=>'16'}   qw(ax bx cx dx r8w r9w r10w r11w r12w r13w r14w r15w si di sp bp));
     %r = (%r, map {$_=>'32a'}  qw(eax  ebx ecx edx esi edi esp ebp));
     %r = (%r, map {$_=>'32b'}  qw(r8d r8l r9d r9l r10d r10l r11d r11l r12d r12l r13d r13l r14d r14l r15d r15l));
     %r = (%r, map {$_=>'f'}    qw(st0 st1 st2 st3 st4 st5 st6 st7));
     %r = (%r, map {$_=>'64'}   qw(rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rsp rbp rip rflags));
     %r = (%r, map {$_=>'64m'}  qw(mm0 mm1 mm2 mm3 mm4 mm5 mm6 mm7));
     %r = (%r, map {$_=>'128'}  qw(xmm0 xmm1 xmm2 xmm3 xmm4 xmm5 xmm6 xmm7 xmm8 xmm9 xmm10 xmm11 xmm12 xmm13 xmm14 xmm15 xmm16 xmm17 xmm18 xmm19 xmm20 xmm21 xmm22 xmm23 xmm24 xmm25 xmm26 xmm27 xmm28 xmm29 xmm30 xmm31));
     %r = (%r, map {$_=>'256'}  qw(ymm0 ymm1 ymm2 ymm3 ymm4 ymm5 ymm6 ymm7 ymm8 ymm9 ymm10 ymm11 ymm12 ymm13 ymm14 ymm15 ymm16 ymm17 ymm18 ymm19 ymm20 ymm21 ymm22 ymm23 ymm24 ymm25 ymm26 ymm27 ymm28 ymm29 ymm30 ymm31));
     %r = (%r, map {$_=>'512'}  qw(zmm0 zmm1 zmm2 zmm3 zmm4 zmm5 zmm6 zmm7 zmm8 zmm9 zmm10 zmm11 zmm12 zmm13 zmm14 zmm15 zmm16 zmm17 zmm18 zmm19 zmm20 zmm21 zmm22 zmm23 zmm24 zmm25 zmm26 zmm27 zmm28 zmm29 zmm30 zmm31));
     %r = (%r, map {$_=>'m'}    qw(k0 k1 k2 k3 k4 k5 k6 k7));

  my @i0 = qw(pushfq rdtsc syscall);                                            # Zero operand instructions
  my @i1 = qw(inc jge jmp jz pop push);                                         # Single operand instructions
  my @i2 =  split /\s+/, <<END;                                                 # Double operand instructions
add and cmp or lea mov shl shr sub test Vmovdqu8 vmovdqu32 vmovdqu64 xor
END
  my @i3 =  split /\s+/, <<END;                                                 # Triple operand instructions
vprolq
END

  for my $r(sort keys %r)
   {eval "sub $r\{q($r)\}";
    confess $@ if $@;
   }

  my %v = map {$_=>1} values %r;
  for my $v(sort keys %v)                                                       # Types of register
   {my @r = grep {$r{$_} eq $v} sort keys %r;
    eval "sub registers_$v\{".dump(\@r)."}";
    confess $@ if $@;
   }

  if (1)                                                                        # Instructions that take zero operands
   {my $s = '';
    for my $i(@i0)
      {my $I = ucfirst $i;
       $s .= <<END;
       sub $I()
        {\@_ == 0 or confess "No arguments allowed";
         push \@text, qq(  $i\\n);
        }
END
     }
    eval $s;
    confess $@ if $@;
   }

  if (1)                                                                        # Instructions that take one operand
   {my $s = '';
    for my $i(@i1)
      {my $I = ucfirst $i;
       $s .= <<END;
       sub $I(\$)
        {my (\$target) = \@_;
         \@_ == 1 or confess "One argument required";
         push \@text, qq(  $i \$target\\n);
        }
END
     }
    eval $s;
    confess $@ if $@;
   }

  if (1)                                                                        # Instructions that take two operands
   {my $s = '';
    for my $i(@i2)
      {my $I = ucfirst $i;
       $s .= <<END;
       sub $I(\$\$)
        {my (\$target, \$source) = \@_;
         \@_ == 2 or confess "Two arguments required";
         push \@text, qq(  $i \$target, \$source\\n);
        }
END
     }
    eval $s;
    confess $@ if $@;
   }

  if (1)                                                                        # Instructions that take three operands
   {my $s = '';
    for my $i(@i3)
      {my $I = ucfirst $i;
       $s .= <<END;
       sub $I(\$\$\$)
        {my (\$target, \$source, \$bits) = \@_;
         \@_ == 3 or confess "Three arguments required";
         push \@text, qq(  $i \$target, \$source, \$bits\\n);
        }
END
     }
    eval $s;
    confess $@ if $@;
   }
 }

sub ClearRegisters(@);                                                          # Clear registers by setting them to zero
sub PrintOutRegisterInHex($);                                                    # Print any register as a hex string
sub Syscall();                                                                  # System call in linux 64 format per: https://filippo.io/linux-syscall-table/

#D1 Generate Network Assembler Code                                             # Generate assembler code that can be assembled with Nasm

my $labels = 0;
sub label                                                                       #P Create a unique label
 {"l".++$labels;                                                                # Generate a label
 }

sub SetLabel($)                                                                 # Set a label in the code section
 {my ($l) = @_;                                                                 # Label
  push @text, <<END;                                                            # Define bytes
  $l:
END
 }

sub Start()                                                                     # Initialize the assembler
 {@bss = @data = @rodata = %rodata = %rodatas = @text = (); $labels = 0;
 }

sub Ds(@)                                                                       # Layout bytes in memory and return their label
 {my (@d) = @_;                                                                 # Data to be laid out
  my $d = join '', @_;
     $d =~ s(') (\')gs;
  my $l = label;
  push @data, <<END;                                                            # Define bytes
  $l: db  '$d';
END
  $l                                                                            # Return label
 }

sub Rs(@)                                                                       # Layout bytes in read only memory and return their label
 {my (@d) = @_;                                                                 # Data to be laid out
  my $d = join '', @_;
     $d =~ s(') (\')gs;
  return $_ if $_ = $rodatas{$d};                                               # Data already exists so return it
  my $l = label;
  $rodatas{$d} = $l;                                                            # Record label
  push @rodata, <<END;                                                          # Define bytes
  $l: db  '$d',0;
END
  $l                                                                            # Return label
 }

sub Dbwdq($@)                                                                   # Layout data
 {my ($s, @d) = @_;                                                             # Element size, data to be laid out
  my $d = join ', ', @d;
  my $l = label;
  push @data, <<END;
  $l: d$s $d
END
  $l                                                                            # Return label
 }

sub Db(@)                                                                       # Layout bytes in the data segment and return their label
 {my (@bytes) = @_;                                                             # Bytes to layout
  Dbwdq 'b', @_;
 }
sub Dw(@)                                                                       # Layout words in the data segment and return their label
 {my (@words) = @_;                                                             # Words to layout
  Dbwdq 'w', @_;
 }
sub Dd(@)                                                                       # Layout double words in the data segment and return their label
 {my (@dwords) = @_;                                                            # Double words to layout
  Dbwdq 'd', @_;
 }
sub Dq(@)                                                                       # Layout quad words in the data segment and return their label
 {my (@qwords) = @_;                                                            # Quad words to layout
  Dbwdq 'q', @_;
 }

sub Rbwdq($@)                                                                   # Layout data
 {my ($s, @d) = @_;                                                             # Element size, data to be laid out
  my $d = join ', ', @d;                                                        # Data to be laid out
  return $_ if $_ = $rodata{$d};                                                # Data already exists so return it
  my $l = label;                                                                # New data - create a label
  push @rodata, <<END;                                                          # Save in read only data
  $l: d$s $d
END
  $rodata{$d} = $l;                                                             # Record label
  $l                                                                            # Return label
 }

sub Rb(@)                                                                       # Layout bytes in the data segment and return their label
 {my (@bytes) = @_;                                                             # Bytes to layout
  Rbwdq 'b', @_;
 }
sub Rw(@)                                                                       # Layout words in the data segment and return their label
 {my (@words) = @_;                                                             # Words to layout
  Rbwdq 'w', @_;
 }
sub Rd(@)                                                                       # Layout double words in the data segment and return their label
 {my (@dwords) = @_;                                                            # Double words to layout
  Rbwdq 'd', @_;
 }
sub Rq(@)                                                                       # Layout quad words in the data segment and return their label
 {my (@qwords) = @_;                                                            # Quad words to layout
  Rbwdq 'q', @_;
 }

sub Comment(@)                                                                  # Insert a comment into the assembly code
 {my (@comment) = @_;                                                           # Text of comment
  my $c = join "", @comment;
  push @text, <<END;
; $c
END
 }

sub Exit(;$)                                                                    # Exit with the specified return code or zero if no return code supplied
 {my ($c) = @_;                                                                 # Return code
  if (@_ == 0 or $c == 0)
   {Comment "Exit code: 0";
    ClearRegisters rdi;
   }
  elsif (@_ == 1)
   {Comment "Exit code: $c";
    Mov rdi, $c;
   }
  Mov rax, 60;
  Syscall;
 }

sub SaveFirstFour()                                                             # Save the first 4 parameter registers
 {Push rax;
  Push rdi;
  Push rsi;
  Push rdx;
  4 * &registerSize(rax);                                                         # Space occupied by push
 }

sub RestoreFirstFour()                                                          # Restore the first 4 parameter registers
 {Pop rdx;
  Pop rsi;
  Pop rdi;
  Pop rax;
 }

sub RestoreFirstFourExceptRax()                                                 # Restore the first 4 parameter registers except rax so it can return its value
 {Pop rdx;
  Pop rsi;
  Pop rdi;
  Add rsp, 8;
 }

sub SaveFirstSeven()                                                            # Save the first 7 parameter registers
 {Push rax;
  Push rdi;
  Push rsi;
  Push rdx;
  Push r10;
  Push r8;
  Push r9;
  7 * registerSize(rax);                                                        # Space occupied by push
 }

sub RestoreFirstSeven()                                                         # Restore the first 7 parameter registers
 {Pop r9;
  Pop r8;
  Pop r10;
  Pop rdx;
  Pop rsi;
  Pop rdi;
  Pop rax;
 }

sub RestoreFirstSevenExceptRax()                                                # Restore the first 7 parameter registers except rax which is being used to return the result
 {Pop r9;
  Pop r8;
  Pop r10;
  Pop rdx;
  Pop rsi;
  Pop rdi;
  Add rsp, registerSize(rax);                                                   # Skip rax
 }

sub If(&;&)                                                                     # If
 {my ($then, $else) = @_;                                                       # Then - required , else - optional
  @_ >= 1 or confess;
  if (@_ == 1)                                                                  # No else
   {Comment "if then";
    my $end = label;
    Jz $end;
    &$then;
    SetLabel $end;
   }
  else                                                                          # With else
   {Comment "if then else";
    my $endIf     = label;
    my $startElse = label;
    Jz $startElse;
    &$then;
    Jmp $endIf;
    SetLabel $startElse;
    &$else;
    SetLabel  $endIf;
   }
 }

sub For(&$$$)                                                                   # For
 {my ($body, $register, $limit, $increment) = @_;                               # Body, register, limit on loop, increment
  @_ == 4 or confess;
  Comment "For $register $limit";
  my $start = label;
  my $end   = label;
  SetLabel $start;
  Cmp $register, $limit;
  Jge $end;

  &$body;

  if ($increment == 1)
   {Inc $register;
   }
  else
   {Add $register, $increment;
   }
  Jmp $start;
  SetLabel $end;
 }

sub registerSize($)                                                             # Return the size of a register
 {my ($r) = @_;                                                                 # Register
  return 16 if $r =~ m(\Ax);
  return 32 if $r =~ m(\Ay);
  return 64 if $r =~ m(\Az);
  8
 }

sub PushR(@)                                                                    # Push registers onto the stack
 {my (@r) = @_;                                                                 # Register
  for my $r(@r)
   {my $size = registerSize $r;
    if    ($size > 8)
     {Sub rsp, $size;
      Vmovdqu32 "[rsp]", $r;
     }
    else
     {Push $r;
     }
   }
 }

sub PopR(@)                                                                     # Pop registers from the stack
 {my (@r) = @_;                                                                 # Register
  for my $r(reverse @r)                                                         # Pop registers in reverse order
   {my $size = registerSize $r;
    if    ($size > 8)
     {Vmovdqu32 $r, "[rsp]";
      Add(rsp, $size);
     }
    else
     {Pop $r;
     }
   }
 }

sub PeekR($)                                                                    # Peek at register on stack
 {my ($r) = @_;                                                                 # Register
  my $size = registerSize $r;
  if    ($size > 8)                                                             # x|y|zmm*
   {Vmovdqu32 $r, "[rsp]";
   }
  else                                                                          # 8 byte register
   {Mov $r, "[rsp]";
   }
 }

sub PrintOutNl()                                                                # Write a new line
 {@_ == 0 or confess;
  my $a = Rb(10);
  Comment "Write new line";
  SaveFirstFour;
  Mov rax, 1;
  Mov rdi, 1;
  Mov rsi, $a;
  Mov rdx, 1;
  Syscall;
  RestoreFirstFour()
 }

sub PrintOutString($;$)                                                         # One: Write a constant string to sysout. Two write the bytes addressed for the specified length to sysout
 {my ($string, $length) = @_;                                                   # String, length
  SaveFirstFour;
  Comment "Write String Out: ", dump(\@_);
  if (@_ == 1)                                                                  # Constant string
   {my ($c) = @_;
    my $l = length($c);
    my $a = Rs($c);
    Mov rax, 1;
    Mov rdi, $sysout;
    Mov rsi, $a;
    Mov rdx, $l;
    Syscall;
   }
  elsif (@_ == 2)                                                               # String, length
   {my ($a, $l) = @_;
    Mov rsi, $a unless $a eq rsi;
    Mov rdx, $l unless $l eq rdx;
    Mov rax, 1;
    Mov rdi, $sysout;
    Syscall;
   }
  else
   {confess "Wrong number of parameters";
   }
  RestoreFirstFour();
 }

sub PrintOutRaxInHex                                                            # Write the content of register rax to stderr in hexadecimal in big endian notation
 {@_ == 0 or confess;
  Comment "Print Rax In Hex";

  my $hexTranslateTable = sub
   {my $h = '0123456789ABCDEF';
    my @t;
    for   my $i(split //, $h)
     {for my $j(split //, $h)
       {push @t, "$i$j";
       }
     }
     Rs @t
   }->();

  my @regs = qw(rax rsi);
  PushR @regs;
  for my $i(0..7)
   {my $s = 8*$i;
    Mov rsi,rax;
    Shl rsi,$s;                                                                 # Push selected byte high
    Shr rsi,56;                                                                 # Push select byte low
    Shl rsi,1;                                                                  # Multiply by two because each entry in the translation table is two bytes long
    Lea rsi, "[$hexTranslateTable+rsi]";
    PrintOutString &rsi, 2;
    PrintOutString ' ' if $i % 2;
   }
  PopR @regs;
 }

sub ClearRegisters(@)                                                           # Clear registers by setting them to zero
 {my (@registers) = @_;                                                         # Registers
  @_ == 1 or confess;
  for my $r(@registers) {&Xor($r,$r)}
 }

sub ReverseBytesInRax                                                           # Reverse the bytes in rax
 {@_ == 0 or confess;
  Comment "Reverse bytes in rax";

  my $size = registerSize rax;
  SaveFirstFour;
  ClearRegisters rsi;
  for(1..$size)                                                                 # Reverse on to stack
   {Mov rdi,rax;
    Shr rdi,($_-1)*8;
    Shl rdi,($size-1)*8;                                                        # Up to end
    Shr rdi,($_-1)*8;
    Or  rsi,rdi;
   }
  Mov rax,rsi;
  RestoreFirstFourExceptRax;
 }

sub PrintOutRaxInReverseInHex                                                   # Write the content of register rax to stderr in hexadecimal in little endian notation
 {@_ == 0 or confess;
  Comment "Print Rax In Reverse In Hex";
  ReverseBytesInRax;
  PrintOutRaxInHex;
 }

sub PrintOutRegisterInHex($)                                                    # Print any register as a hex string
 {my ($r) = @_;                                                                 # Name of the register to print
  Comment "Print register $r in Hex";
  @_ == 1 or confess;
  PrintOutString sprintf("%6s: ", $r);

  my sub printReg(@)                                                            # Print the contents of a register
   {my (@regs) = @_;                                                            # Size in bytes, work registers
    my $s = registerSize $r;                                                    # Size of the register
    PushR @regs;                                                                # Save work registers
    PushR $r;                                                                   # Place register contents on stack
    PopR  @regs;                                                                # Load work registers
    for my $R(@regs)                                                            # Print work registers to print input register
     {if ($R !~ m(\Arax))
       {PrintOutString("  ");
        Mov rax, $R
       }
      PrintOutRaxInHex;                                                         # Print work register
     }
    PopR @regs;
   };
  if    ($r =~ m(\Ar)) {printReg qw(rax)}                                       # 64 bit register requested
  elsif ($r =~ m(\Ax)) {printReg qw(rax rbx)}                                   # xmm*
  elsif ($r =~ m(\Ay)) {printReg qw(rax rbx rcx rdx)}                           # ymm*
  elsif ($r =~ m(\Az)) {printReg qw(rax rbx rcx rdx r8 r9 r10 r11)}             # zmm*

  PrintOutNl;
 }

sub PrintOutRipInHex                                                            # Print the instruction pointer in hex
 {@_ == 0 or confess;
  my @regs = qw(rax);
  PushR @regs;
  my $l = label;
  push @text, <<END;
$l:
END
  Lea rax, "[$l]";                                                              # Current instruction pointer
  PrintOutString "rip: ";
  PrintOutRaxInHex;
  PrintOutNl;
  PopR @regs;
 }

sub PrintOutRflagsInHex                                                         # Print the flags register in hex
 {@_ == 0 or confess;
  my @regs = qw(rax);
  PushR @regs;
  Pushfq;
  Pop rax;
  PrintOutString "rfl: ";
  PrintOutRaxInHex;
  PrintOutNl;
  PopR @regs;
 }

sub PrintOutRegistersInHex                                                      # Print the general purpose registers in hex
 {@_ == 0 or confess;

  PrintOutRipInHex;
  PrintOutRflagsInHex;

  my @regs = qw(rax);
  PushR @regs;

  my $w = registers_64();
  for my $r(sort @$w)
   {next if $r =~ m(rip|rflags);
    if ($r eq rax)
     {Pop rax;
      Push rax
     }
    PrintOutString reverse(pad(reverse($r), 3)).": ";
    Mov rax, $r;
    PrintOutRaxInHex;
    PrintOutNl;
   }
  PopR @regs;
 }

sub PrintOutMemoryInHex($$)                                                     # Print the specified number of bytes from the specified address in hex
 {my ($addr, $length) = @_;                                                     # Address, length
  SaveFirstSeven;
  Comment "Print out memory in hex: $addr, $length";
  my $size = registerSize rax;
  Mov r8, $addr;
  Mov r9, r8;
  Add r9, $length;
  Sub r9, $size;
  For                                                                           # Print string in blocks
   {Mov rax, "[r8]";
    ReverseBytesInRax;
    PrintOutRaxInHex;
   } r8, r9, $size;
  RestoreFirstSeven()
 }

sub allocateMemory($)                                                           # Allocate memory via mmap
 {my ($s) = @_;                                                                 # Amount of memory to allocate
  @_ == 1 or confess;
  Comment "Allocate $s bytes of memory";
  SaveFirstSeven;
  my $d = extractMacroDefinitionsFromCHeaderFile "linux/mman.h";                # mmap constants
  my $pa = $$d{MAP_PRIVATE} | $$d{MAP_ANONYMOUS};
  my $wr = $$d{PROT_WRITE}  | $$d{PROT_READ};

  Mov rax, 9;                                                                   # mmap
  Xor rdi, rdi;                                                                 # Anywhere
  Mov rsi, $s;                                                                  # Amount of memory
  Mov rdx, $wr;                                                                 # Read write protections
  Mov r10, $pa;                                                                 # Private and anonymous map
  Mov r8,  -1;                                                                  # File descriptor for file backing memory if any
  Mov r9,  0;                                                                   # Offset into file
  Syscall;
  RestoreFirstSevenExceptRax;
 }

=pod
_
sub ReadFileIntoMemory($)                                                       # Read a file into memory using mmap
 {my ($file) = @_;                                                              # address of file name
  @_ == 1 or confess;
  Comment "Read a file into memeory $file";
  SaveFirstSeven;
  my $d = extractMacroDefinitionsFromCHeaderFile "linux/mman.h";                # mmap constants
  my $pa = $$d{MAP_PRIVATE} | $$d{MAP_ANONYMOUS};
  my $wr = $$d{PROT_WRITE}  | $$d{PROT_READ};

  Mov rax, 9;                                                                   # mmap
  Xor rdi, rdi;                                                                 # Anywhere
  Mov rsi, $s;                                                                  # Amount of memory
  Mov rdx, $wr;                                                                 # PROT_WRITE  | PROT_READ
  Mov r10, $pa;                                                                 # MAP_PRIVATE | MAP_ANON
  Mov r8,  -1;                                                                  # File descriptor for file backing memory if any
  Mov r9,  0;                                                                   # Offset into file
  Syscall;
  RestoreFirstSevenExceptRax;
 }
=cut

sub freeMemory($$)                                                              # Free memory via mmap
 {my ($a, $l) = @_;                                                             # Address of memory to free, length of memory to free
  @_ == 2 or confess;
  Comment "Free memory at:  $a length: $l";
  SaveFirstFour;
  Mov rax, 11;                                                                  # unmmap
  Mov rdi, $a;                                                                  # Address
  Mov rsi, $l;                                                                  # Length
  Syscall;                                                                      # unmmap $a, $l
  RestoreFirstFourExceptRax;
 }

sub Fork()                                                                      # Fork
 {@_ == 0 or confess;
  Comment "Fork";
  Mov rax, 57;
  Syscall
 }

sub GetPid()                                                                    # Get process identifier
 {@_ == 0 or confess;
  Comment "Get Pid";

  Mov rax, 39;
  Syscall
 }

sub GetPPid()                                                                   # Get parent process identifier
 {@_ == 0 or confess;
  Comment "Get Parent Pid";

  Mov rax, 110;
  Syscall
 }

sub GetUid()                                                                    # Get userid of current process
 {@_ == 0 or confess;
  Comment "Get User id";

  Mov rax, 102;
  Syscall
 }

sub WaitPid()                                                                   # Wait for the pid in rax to complete
 {@_ == 0 or confess;
  Comment "WaitPid - wait for the pid in rax";
  SaveFirstSeven;
  Mov rdi,rax;
  Mov rax, 61;
  Mov rsi, 0;
  Mov rdx, 0;
  Mov r10, 0;
  Syscall;
  RestoreFirstSevenExceptRax;
 }

sub readTimeStampCounter()                                                      # Read the time stamp counter
 {@_ == 0 or confess;
  Comment "Read Time-Stamp Counter";
  Push rdx;
  Rdtsc;
  Shl rdx,32;                                                                   # Or upper half into rax
  Or rax,rdx;
  Pop rdx;
  RestoreFirstFourExceptRax;
 }

sub OpenRead($)                                                                 # Open a file for read
 {my ($file) = @_;                                                              # File
  @_ == 1 or confess;
  Comment "Open a file for read";
  my $S = extractMacroDefinitionsFromCHeaderFile "asm-generic/fcntl.h";         # Constants for reading a file
  my $O_RDONLY = $$S{O_RDONLY};
  SaveFirstFour;
  Mov rax,2;
  Mov rdi,$file;
  Mov rsi,$O_RDONLY;
  Xor rdx,rdx;
  Syscall;
  RestoreFirstFourExceptRax;
 }

sub Close($)                                                                    # Close a file descriptor
 {my ($fdes) = @_;                                                              # File descriptor
  @_ == 1 or confess;
  Comment "Close a file";
  SaveFirstFour;
  Mov rdi,$fdes;
  Mov rax,3;
  Syscall;
  RestoreFirstFourExceptRax;
 }

sub localData()                                                                 # Map local data
 {@_ == 0 or confess;
  my $local = genHash("LocalData",
    size      => 0,
    variables => [],
   );
 }

sub LocalData::start($)                                                         # Start a local data area on the stack
 {my ($local) = @_;                                                             # Local data descriptor
  @_ == 1 or confess;
  my $size = $local->size;                                                      # Size of local data
  Sub rsp, $size;
 }

sub LocalData::free($)                                                          # Free a local data area on the stack
 {my ($local) = @_;                                                             # Local data descriptor
  @_ == 1 or confess;
  my $size = $local->size;                                                      # Size of local data
  Add rsp, $size;
 }

sub LocalData::variable($$;$)                                                   # Add a local variable
 {my ($local, $length, $comment) = @_;                                          # Local data descriptor, length of data, optional comment
  @_ >= 2 or confess;
  my $variable = genHash("LocalVariable",
    loc        => $local->size,
    size       => $length,
    comment    => $comment
   );
  $local->size += $length;                                                      # Update size of local data
  $variable
 }

sub LocalVariable::stack($)                                                     # Address a local variable on the stack
 {my ($variable) = @_;                                                          # Variable
  @_ == 1 or confess;
  my $loc = $variable->loc;                                                     # Location of variable on stack
  "[$loc+rsp]"                                                                  # Address variable
 }

sub LocalData::allocate8($;$)                                                   # Add an 8 byte local variable
 {my ($local, $comment) = @_;                                                   # Local data descriptor, optional comment
  LocalData::variable($local, 8, $comment);
 }

sub MemoryClear($$)                                                             # Clear memory
 {my ($addr, $length) = @_;                                                     # Stack offset of buffer address, stack offset of length of buffer
  @_ == 2 or confess;
  Comment "Clear memory $addr $length";

  my $size = registerSize rax;
  my $saveSize = SaveFirstSeven;                                                 # Generated code
  Mov rdi, "[$addr   +$saveSize+rsp]";                                        # Address of buffer
  Mov rsi, rdi;
  Add rsi, "[$length  +$saveSize+rsp]";
  Sub rsi, $size;
  Xor rdx,rdx;
  Mov rdx, 0x61626364;
  Shl rdx,32;
  Or  rdx, 0x65666768;
  For                                                                           # Clear and test memory
   {Mov "[rdi]", rdx;
    Mov r8, "[rdi]";
    Cmp r8,rdx;
   } rdi, rsi, registerSize(rax);

  RestoreFirstSevenExceptRax;
 }

sub Read($$$)                                                                   # Read data the specified file descriptor into the specified buffer of specified length
 {my ($fileDes, $addr, $length) = @_;                                           # Stack offset of file descriptor, stack offset of buffer address, stack offset of length of buffer
  @_ == 3 or confess;
  Comment "Read data into memory";

  my $saveSize = SaveFirstFour;                                                 # Generated code
  Mov rdi, "$fileDes+$saveSize+rsp]";                                           # File descriptor
  Mov rsi, "$addr   +$saveSize+rsp]";                                           # Address of buffer
  Mov rdx, "$length +$saveSize+rsp]";                                           # Length of buffer
  Syscall;
  PrintOutRegistersInHex;
  RestoreFirstFourExceptRax;
 }

sub ReadFile($$)                                                                # Read a file into memory returning its address and length in the named x|y|zmm* register
 {my ($file, $reg) = @_;                                                        # File, register
  @_ == 2 or confess;
  Comment "Read a file into memory";

  my $local      = localData;                                                   # Local data
  my $bufferAddr = $local->allocate8;
  my $fileSize   = $local->allocate8;
  my $fileDes    = $local->allocate8;

  SaveFirstFour;                                                                # Generated code
  $local->start;                                                                # Start local data on stack
  StatSize($file);                                                              # File size
  Mov $fileSize->stack, rax;                                                    # Save file size
  allocateMemory(rax);                                                          # Memory for data in file
  Mov $bufferAddr->stack, rax;                                                  # Save memory location
  MemoryClear $bufferAddr->loc, $fileSize->loc;
  OpenRead($file);                                                              # Open file for read
  Mov $fileDes->stack, rax;                                                     # Save file descriptor
  Read $fileDes->loc, $bufferAddr->loc, $fileSize->loc;                         # Read the entire file into the allocated memory
  Close $fileDes->loc;
  Vmovdqu64 $reg, "[rsp]";                                                      # Load stack into specified register to save buffer address and length
  $local->free;                                                                 # Release local data on stack
  RestoreFirstFour;
 }

sub StatSize($)                                                                 # Stat a file to get its size in rax
 {my ($file) = @_;                                                              # File
  @_ == 1 or confess;
  Comment "Stat a file for size";
  my $S = extractCStructure "#include <sys/stat.h>";                            # Get location of size field
  my $Size = $$S{stat}{size};
  my $off  = $$S{stat}{fields}{st_size}{loc};
  SaveFirstFour;
  Mov rax,4;
  Mov rdi,$file;
  Lea rsi, "[rsp-$Size]";
  Syscall;
  Mov rax, "[$off+rsp-$Size]";                                                  # Place size in rax
  RestoreFirstFourExceptRax;
 }

sub assemble(%)                                                                 # Assemble the generated code
 {my (%options) = @_;                                                           # Options
  my $r = join "\n", map {s/\s+\Z//sr} @rodata;
  my $d = join "\n", map {s/\s+\Z//sr} @data;
  my $b = join "\n", map {s/\s+\Z//sr} @bss;
  my $t = join "\n", map {s/\s+\Z//sr} @text;
  my $a = <<END;
section .rodata
  $r
section .data
  $d
section .bss
  $b
section .text
global _start, main
  _start:
  main:
  push rbp     ; function prologue
  mov  rbp,rsp
  $t
END

  my $c    = owf(q(z.asm), $a);                                                 # Source file
  my $e    =     q(z);                                                          # Executable file
  my $l    =     q(z.txt);                                                      # Assembler listing
  my $o    =     q(z.o);                                                        # Object file

  my $cmd  = qq(nasm -f elf64 -g -l $l -o $o $c; ld -o $e $o; chmod 744 $e; $sde -ptr-check -- ./$e 2>&1);
  say STDERR qq($cmd);
  my $R    = eval {qx($cmd)};
  say STDERR readFile($l) if $options{list};                                    # Print listing if requested
  say STDERR $R;
  $R                                                                            # Return execution results
 }

#d
#-------------------------------------------------------------------------------
# Export - eeee
#-------------------------------------------------------------------------------

use Exporter qw(import);

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA          = qw(Exporter);
@EXPORT       = qw();
@EXPORT_OK    = qw(
 );
%EXPORT_TAGS = (all=>[@EXPORT, @EXPORT_OK]);

# podDocumentation
=pod

=encoding utf-8

=head1 Name

Nasm::X86 - Generate Nasm assembler code

=head1 Synopsis

Write and run some assembler code to start a child process and wait for it,
printing out the process identifiers of each process involved:

  Start;                                                                        # Start the program
  Fork;                                                                         # Fork

  Test rax,rax;
  If                                                                            # Parent
   {Mov rbx, rax;
    WaitPid;
    PrintOutRegisterInHex rax;
    PrintOutRegisterInHex rbx;
    GetPid;                                                                     # Pid of parent as seen in parent
    Mov rcx,rax;
    PrintOutRegisterInHex rcx;
   }
  sub                                                                           # Child
   {Mov r8,rax;
    PrintOutRegisterInHex r8;
    GetPid;                                                                     # Child pid as seen in child
    Mov r9,rax;
    PrintOutRegisterInHex r9;
    GetPPid;                                                                    # Parent pid as seen in child
    Mov r10,rax;
    PrintOutRegisterInHex r10;
   };

  Exit;                                                                         # Return to operating system

  my $r = assemble();

  #    r8: 0000 0000 0000 0000   #1 Return from fork as seen by child
  #    r9: 0000 0000 0003 0C63   #2 Pid of child
  #   r10: 0000 0000 0003 0C60   #3 Pid of parent from child
  #   rax: 0000 0000 0003 0C63   #4 Return from fork as seen by parent
  #   rbx: 0000 0000 0003 0C63   #5 Wait for child pid result
  #   rcx: 0000 0000 0003 0C60   #6 Pid of parent

Get the size of this file:

  Start;                                                                        # Start the program
  my $f = Rs($0);                                                               # File to stat
  StatSize($f);                                                                 # Stat the file
  PrintOutRegisterInHex rax;
  Exit;                                                                         # Return to operating system

  my $r = assemble() =~ s( ) ()gsr;
  if ($r =~ m(rax:([0-9a-f]{16}))is)                                            # Compare file size obtained with that from fileSize()
   {is_deeply $1, sprintf("%016X", fileSize($0));
   }

=head2 Installation

You will need the Intel Software Development Emulator and the Networkwide
Assembler installed on your test system.  For full details of how to do this
see: L<https://github.com/philiprbrenan/NasmX86/blob/main/.github/workflows/main.yml>

=head1 Description

Generate Nasm assembler code


Version "202104010".


The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see L<Index|/Index>.



=head1 Generate Network Assembler Code

Generate assembler code that can be assembled with Nasm

=head2 SetLabel($l)

Set a label in the code section

     Parameter  Description
  1  $l         Label

=head2 Start()

Initialize the assembler


B<Example:>



    Start;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    PrintOutString "Hello World";
    Exit;
    ok assemble =~ m(Hello World);


=head2 Ds(@d)

Layout bytes in memory and return their label

     Parameter  Description
  1  @d         Data to be laid out

B<Example:>


    Start;
    my $q = Rs('a'..'z');

    my $d = Ds('0'x64);                                                           # Output area  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    Vmovdqu32(xmm0, "[$q]");                                                      # Load
    Vprolq   (xmm0,   xmm0, 32);                                                  # Rotate double words in quad words
    Vmovdqu32("[$d]", xmm0);                                                      # Save
    PrintOutString($d, 16);
    Exit;
    ok assemble() =~ m(efghabcdmnopijkl)s;


=head2 Rs(@d)

Layout bytes in read only memory and return their label

     Parameter  Description
  1  @d         Data to be laid out

B<Example:>


    Start;
    Comment "Print a string from memory";
    my $s = "Hello World";

    my $m = Rs($s);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    Mov rsi, $m;
    PrintOutString rsi, length($s);
    Exit;
    ok assemble =~ m(Hello World);


=head2 Dbwdq($s, @d)

Layout data

     Parameter  Description
  1  $s         Element size
  2  @d         Data to be laid out

=head2 Db(@bytes)

Layout bytes in the data segment and return their label

     Parameter  Description
  1  @bytes     Bytes to layout

=head2 Dw(@words)

Layout words in the data segment and return their label

     Parameter  Description
  1  @words     Words to layout

=head2 Dd(@dwords)

Layout double words in the data segment and return their label

     Parameter  Description
  1  @dwords    Double words to layout

=head2 Dq(@qwords)

Layout quad words in the data segment and return their label

     Parameter  Description
  1  @qwords    Quad words to layout

=head2 Rbwdq($s, @d)

Layout data

     Parameter  Description
  1  $s         Element size
  2  @d         Data to be laid out

=head2 Rb(@bytes)

Layout bytes in the data segment and return their label

     Parameter  Description
  1  @bytes     Bytes to layout

=head2 Rw(@words)

Layout words in the data segment and return their label

     Parameter  Description
  1  @words     Words to layout

=head2 Rd(@dwords)

Layout double words in the data segment and return their label

     Parameter  Description
  1  @dwords    Double words to layout

=head2 Rq(@qwords)

Layout quad words in the data segment and return their label

     Parameter  Description
  1  @qwords    Quad words to layout

=head2 Comment(@comment)

Insert a comment into the assembly code

     Parameter  Description
  1  @comment   Text of comment

B<Example:>


    Start;

    Comment "Print a string from memory";  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    my $s = "Hello World";
    my $m = Rs($s);
    Mov rsi, $m;
    PrintOutString rsi, length($s);
    Exit;
    ok assemble =~ m(Hello World);


=head2 Exit($c)

Exit with the specified return code or zero if no return code supplied

     Parameter  Description
  1  $c         Return code

B<Example:>


    Start;
    PrintOutString "Hello World";

    Exit;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    ok assemble =~ m(Hello World);


=head2 SaveFirstFour()

Save the first 4 parameter registers


=head2 RestoreFirstFour()

Restore the first 4 parameter registers


=head2 RestoreFirstFourExceptRax()

Restore the first 4 parameter registers except rax so it can return its value


=head2 SaveFirstSeven()

Save the first 7 parameter registers


=head2 RestoreFirstSeven()

Restore the first 7 parameter registers


=head2 RestoreFirstSevenExceptRax()

Restore the first 7 parameter registers except rax which is being used to return the result


=head2 If($then, $else)

If

     Parameter  Description
  1  $then      Then - required
  2  $else      Else - optional

B<Example:>


    Start;
    Mov rax, 0;
    Test rax,rax;

    If  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

     {PrintOutRegisterInHex rax;
     } sub
     {PrintOutRegisterInHex rbx;
     };
    Mov rax, 1;
    Test rax,rax;

    If  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

     {PrintOutRegisterInHex rcx;
     } sub
     {PrintOutRegisterInHex rdx;
     };
    Exit;
    ok assemble() =~ m(rbx.*rcx)s;


=head2 For($body, $register, $limit, $increment)

For

     Parameter   Description
  1  $body       Body
  2  $register   Register
  3  $limit      Limit on loop
  4  $increment  Increment

=head2 registerSize($r)

Return the size of a register

     Parameter  Description
  1  $r         Register

=head2 PushR(@r)

Push registers onto the stack

     Parameter  Description
  1  @r         Register

=head2 PopR(@r)

Pop registers from the stack

     Parameter  Description
  1  @r         Register

B<Example:>


    Start;
    my $q = Rs(('a'..'p')x4);
    my $d = Ds('0'x128);
    Vmovdqu32(zmm0, "[$q]");
    Vprolq   (zmm0,   zmm0, 32);
    Vmovdqu32("[$d]", zmm0);
    PrintOutString($d, 64);
    Sub rsp, 64;
    Vmovdqu64 "[rsp]", zmm0;

    PopR rax;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    PrintOutRaxInHex;
    Exit;
    ok assemble() =~ m(efghabcdmnopijklefghabcdmnopijklefghabcdmnopijklefghabcdmnopijkl)s;


=head2 PeekR($r)

Peek at register on stack

     Parameter  Description
  1  $r         Register

=head2 PrintOutNl()

Write a new line


B<Example:>


    Start;
    Comment "Print a string from memory";
    my $s = "Hello World";
    my $m = Rs($s);
    Mov rsi, $m;
    PrintOutString rsi, length($s);
    Exit;
    ok assemble =~ m(Hello World);


=head2 PrintOutString($string, $length)

One: Write a constant string to sysout. Two write the bytes addressed for the specified length to sysout

     Parameter  Description
  1  $string    String
  2  $length    Length

B<Example:>


    Start;

    PrintOutString "Hello World";  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    Exit;
    ok assemble =~ m(Hello World);


=head2 PrintOutRaxInHex()

Write the content of register rax to stderr in hexadecimal in big endian notation


B<Example:>


    Start;
    my $q = Rs('abababab');
    Mov(rax, "[$q]");
    PrintOutString "rax: ";

    PrintOutRaxInHex;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    PrintOutNl;
    Xor rax, rax;
    PrintOutString "rax: ";

    PrintOutRaxInHex;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    PrintOutNl;
    Exit;
    ok assemble() =~ m(rax: 6261 6261 6261 6261.*rax: 0000 0000 0000 0000)s;


=head2 ClearRegisters(@registers)

Clear registers by setting them to zero

     Parameter   Description
  1  @registers  Registers

=head2 ReverseBytesInRax()

Reverse the bytes in rax


=head2 PrintOutRaxInReverseInHex()

Write the content of register rax to stderr in hexadecimal in little endian notation


B<Example:>


    Start;
    Mov rax, 0x88776655;
    Shl rax, 32;
    Or  rax, 0x44332211;
    PrintOutRaxInHex;

    PrintOutRaxInReverseInHex;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    Exit;
    ok assemble() =~ m(8877 6655 4433 2211 1122 3344 5566 7788)s;


=head2 PrintOutRegisterInHex($r)

Print any register as a hex string

     Parameter  Description
  1  $r         Name of the register to print

B<Example:>


    Start;
    my $q = Rs(('a'..'p')x4);
    Mov r8,"[$q]";

    PrintOutRegisterInHex r8;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    Exit;
    ok assemble() =~ m(r8: 6867 6665 6463 6261)s;


=head2 PrintOutRipInHex()

Print the instruction pointer in hex


=head2 PrintOutRflagsInHex()

Print the flags register in hex


=head2 PrintOutRegistersInHex()

Print the general purpose registers in hex


B<Example:>


    Start;
    my $q = Rs('abababab');
    Mov(rax, 1);
    Mov(rbx, 2);
    Mov(rcx, 3);
    Mov(rdx, 4);
    Mov(r8,  5);
    Lea r9,  "[rax+rbx]";

    PrintOutRegistersInHex;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    Exit;
    my $r = assemble();
    ok $r =~ m( r8: 0000 0000 0000 0005.* r9: 0000 0000 0000 0003.*rax: 0000 0000 0000 0001)s;
    ok $r =~ m(rbx: 0000 0000 0000 0002.*rcx: 0000 0000 0000 0003.*rdx: 0000 0000 0000 0004)s;


=head2 PrintOutMemoryInHex($addr, $length)

Print the specified number of bytes from the specified address in hex

     Parameter  Description
  1  $addr      Address
  2  $length    Length

=head2 allocateMemory($s)

Allocate memory via mmap

     Parameter  Description
  1  $s         Amount of memory to allocate

B<Example:>


    Start;
    my $N = 2048;
    my $n = Rq($N);
    my $q = Rs('a'..'p');

    allocateMemory "[$n]";  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    PrintOutRegisterInHex rax;
    Vmovdqu8 xmm0, "[$q]";
    Vmovdqu8 "[rax]", xmm0;
    PrintOutString rax,16;
    PrintOutNl;

    Mov rbx, rax;
    freeMemory rbx, "[$n]";
    PrintOutRegisterInHex rax;
    Vmovdqu8 "[rbx]", xmm0;
    Exit;
    ok assemble() =~ m(abcdefghijklmnop)s;

    Start;
    my $N = 4096;
    my $S = registerSize rax;

    allocateMemory $N;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    PrintOutRegistersInHex;
    Mov rbx, $N;
    PushR rbx;
    PushR rax;
    MemoryClear 0, $S;
    Mov rbx, $N-5;
    PrintOutString rax, rbx;
    PrintOutMemoryInHex rax, rbx;
    Exit;
    ok assemble() =~ m(abcdefghijklmnop)s;


=head2 ReadFileIntoMemory($file)

Read a file into memory using mmap

     Parameter  Description
  1  $file      Address of file name

=head2 freeMemory($a, $l)

Free memory via mmap

     Parameter  Description
  1  $a         Address of memory to free
  2  $l         Length of memory to free

B<Example:>


    Start;
    my $N = 2048;
    my $n = Rq($N);
    my $q = Rs('a'..'p');
    allocateMemory "[$n]";
    PrintOutRegisterInHex rax;
    Vmovdqu8 xmm0, "[$q]";
    Vmovdqu8 "[rax]", xmm0;
    PrintOutString rax,16;
    PrintOutNl;

    Mov rbx, rax;

    freeMemory rbx, "[$n]";  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    PrintOutRegisterInHex rax;
    Vmovdqu8 "[rbx]", xmm0;
    Exit;
    ok assemble() =~ m(abcdefghijklmnop)s;

    Start;
    my $N = 4096;
    my $S = registerSize rax;
    allocateMemory $N;
    PrintOutRegistersInHex;
    Mov rbx, $N;
    PushR rbx;
    PushR rax;
    MemoryClear 0, $S;
    Mov rbx, $N-5;
    PrintOutString rax, rbx;
    PrintOutMemoryInHex rax, rbx;
    Exit;
    ok assemble() =~ m(abcdefghijklmnop)s;


=head2 Fork()

Fork


B<Example:>


    Start;                                                                        # Start the program

    Fork;                                                                         # Fork  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


    Test rax,rax;
    If                                                                            # Parent
     {Mov rbx, rax;
      WaitPid;
      PrintOutRegisterInHex rax;
      PrintOutRegisterInHex rbx;
      GetPid;                                                                     # Pid of parent as seen in parent
      Mov rcx,rax;
      PrintOutRegisterInHex rcx;
     }
    sub                                                                           # Child
     {Mov r8,rax;
      PrintOutRegisterInHex r8;
      GetPid;                                                                     # Child pid as seen in child
      Mov r9,rax;
      PrintOutRegisterInHex r9;
      GetPPid;                                                                    # Parent pid as seen in child
      Mov r10,rax;
      PrintOutRegisterInHex r10;
     };

    Exit;                                                                         # Return to operating system

    my $r = assemble();

  #    r8: 0000 0000 0000 0000   #1 Return from fork as seen by child
  #    r9: 0000 0000 0003 0C63   #2 Pid of child
  #   r10: 0000 0000 0003 0C60   #3 Pid of parent from child
  #   rax: 0000 0000 0003 0C63   #4 Return from fork as seen by parent
  #   rbx: 0000 0000 0003 0C63   #5 Wait for child pid result
  #   rcx: 0000 0000 0003 0C60   #6 Pid of parent

    if ($r =~ m(r8:( 0000){4}.*r9:(.*)\s{5,}r10:(.*)\s{5,}rax:(.*)\s{5,}rbx:(.*)\s{5,}rcx:(.*)\s{2,})s)
     {ok $2 eq $4;
      ok $2 eq $5;
      ok $3 eq $6;
      ok $2 gt $6;
     }

    Start;                                                                        # Start the program
    GetUid;                                                                       # Userid
    PrintOutRegisterInHex rax;
    Exit;                                                                         # Return to operating system
    my $r = assemble();
    ok $r =~ m(rax:( 0000){3});


=head2 GetPid()

Get process identifier


B<Example:>


    Start;                                                                        # Start the program
    Fork;                                                                         # Fork

    Test rax,rax;
    If                                                                            # Parent
     {Mov rbx, rax;
      WaitPid;
      PrintOutRegisterInHex rax;
      PrintOutRegisterInHex rbx;

      GetPid;                                                                     # Pid of parent as seen in parent  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      Mov rcx,rax;
      PrintOutRegisterInHex rcx;
     }
    sub                                                                           # Child
     {Mov r8,rax;
      PrintOutRegisterInHex r8;

      GetPid;                                                                     # Child pid as seen in child  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      Mov r9,rax;
      PrintOutRegisterInHex r9;
      GetPPid;                                                                    # Parent pid as seen in child
      Mov r10,rax;
      PrintOutRegisterInHex r10;
     };

    Exit;                                                                         # Return to operating system

    my $r = assemble();

  #    r8: 0000 0000 0000 0000   #1 Return from fork as seen by child
  #    r9: 0000 0000 0003 0C63   #2 Pid of child
  #   r10: 0000 0000 0003 0C60   #3 Pid of parent from child
  #   rax: 0000 0000 0003 0C63   #4 Return from fork as seen by parent
  #   rbx: 0000 0000 0003 0C63   #5 Wait for child pid result
  #   rcx: 0000 0000 0003 0C60   #6 Pid of parent

    if ($r =~ m(r8:( 0000){4}.*r9:(.*)\s{5,}r10:(.*)\s{5,}rax:(.*)\s{5,}rbx:(.*)\s{5,}rcx:(.*)\s{2,})s)
     {ok $2 eq $4;
      ok $2 eq $5;
      ok $3 eq $6;
      ok $2 gt $6;
     }

    Start;                                                                        # Start the program
    GetUid;                                                                       # Userid
    PrintOutRegisterInHex rax;
    Exit;                                                                         # Return to operating system
    my $r = assemble();
    ok $r =~ m(rax:( 0000){3});


=head2 GetPPid()

Get parent process identifier


B<Example:>


    Start;                                                                        # Start the program
    Fork;                                                                         # Fork

    Test rax,rax;
    If                                                                            # Parent
     {Mov rbx, rax;
      WaitPid;
      PrintOutRegisterInHex rax;
      PrintOutRegisterInHex rbx;
      GetPid;                                                                     # Pid of parent as seen in parent
      Mov rcx,rax;
      PrintOutRegisterInHex rcx;
     }
    sub                                                                           # Child
     {Mov r8,rax;
      PrintOutRegisterInHex r8;
      GetPid;                                                                     # Child pid as seen in child
      Mov r9,rax;
      PrintOutRegisterInHex r9;

      GetPPid;                                                                    # Parent pid as seen in child  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      Mov r10,rax;
      PrintOutRegisterInHex r10;
     };

    Exit;                                                                         # Return to operating system

    my $r = assemble();

  #    r8: 0000 0000 0000 0000   #1 Return from fork as seen by child
  #    r9: 0000 0000 0003 0C63   #2 Pid of child
  #   r10: 0000 0000 0003 0C60   #3 Pid of parent from child
  #   rax: 0000 0000 0003 0C63   #4 Return from fork as seen by parent
  #   rbx: 0000 0000 0003 0C63   #5 Wait for child pid result
  #   rcx: 0000 0000 0003 0C60   #6 Pid of parent

    if ($r =~ m(r8:( 0000){4}.*r9:(.*)\s{5,}r10:(.*)\s{5,}rax:(.*)\s{5,}rbx:(.*)\s{5,}rcx:(.*)\s{2,})s)
     {ok $2 eq $4;
      ok $2 eq $5;
      ok $3 eq $6;
      ok $2 gt $6;
     }

    Start;                                                                        # Start the program
    GetUid;                                                                       # Userid
    PrintOutRegisterInHex rax;
    Exit;                                                                         # Return to operating system
    my $r = assemble();
    ok $r =~ m(rax:( 0000){3});


=head2 GetUid()

Get userid of current process


=head2 WaitPid()

Wait for the pid in rax to complete


B<Example:>


    Start;                                                                        # Start the program
    Fork;                                                                         # Fork

    Test rax,rax;
    If                                                                            # Parent
     {Mov rbx, rax;

      WaitPid;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      PrintOutRegisterInHex rax;
      PrintOutRegisterInHex rbx;
      GetPid;                                                                     # Pid of parent as seen in parent
      Mov rcx,rax;
      PrintOutRegisterInHex rcx;
     }
    sub                                                                           # Child
     {Mov r8,rax;
      PrintOutRegisterInHex r8;
      GetPid;                                                                     # Child pid as seen in child
      Mov r9,rax;
      PrintOutRegisterInHex r9;
      GetPPid;                                                                    # Parent pid as seen in child
      Mov r10,rax;
      PrintOutRegisterInHex r10;
     };

    Exit;                                                                         # Return to operating system

    my $r = assemble();

  #    r8: 0000 0000 0000 0000   #1 Return from fork as seen by child
  #    r9: 0000 0000 0003 0C63   #2 Pid of child
  #   r10: 0000 0000 0003 0C60   #3 Pid of parent from child
  #   rax: 0000 0000 0003 0C63   #4 Return from fork as seen by parent
  #   rbx: 0000 0000 0003 0C63   #5 Wait for child pid result
  #   rcx: 0000 0000 0003 0C60   #6 Pid of parent

    if ($r =~ m(r8:( 0000){4}.*r9:(.*)\s{5,}r10:(.*)\s{5,}rax:(.*)\s{5,}rbx:(.*)\s{5,}rcx:(.*)\s{2,})s)
     {ok $2 eq $4;
      ok $2 eq $5;
      ok $3 eq $6;
      ok $2 gt $6;
     }

    Start;                                                                        # Start the program
    GetUid;                                                                       # Userid
    PrintOutRegisterInHex rax;
    Exit;                                                                         # Return to operating system
    my $r = assemble();
    ok $r =~ m(rax:( 0000){3});


=head2 readTimeStampCounter()

Read the time stamp counter


B<Example:>


    Start;
    for(1..10)

     {readTimeStampCounter;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      PrintOutRegisterInHex rax;
     }
    Exit;
    my @s = split /
/, assemble();
    my @S = sort @s;
    is_deeply \@s, \@S;


=head2 OpenRead($file)

Open a file for read

     Parameter  Description
  1  $file      File

B<Example:>


    Start;                                                                        # Start the program
    my $f = Rs($0);                                                               # File to stat

    OpenRead($f);                                                                 # Open file  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    PrintOutRegisterInHex rax;
    Close(rax);                                                                   # Close file
    PrintOutRegisterInHex rax;
    Exit;                                                                         # Return to operating system
    my $r = assemble();
    ok $r =~ m(( 0000){3} 0003)i;                                                 # Expected file number
    ok $r =~ m(( 0000){4})i;                                                      # Expected file number


=head2 Close($fdes)

Close a file descriptor

     Parameter  Description
  1  $fdes      File descriptor

B<Example:>


    Start;                                                                        # Start the program
    my $f = Rs($0);                                                               # File to stat
    OpenRead($f);                                                                 # Open file
    PrintOutRegisterInHex rax;

    Close(rax);                                                                   # Close file  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    PrintOutRegisterInHex rax;
    Exit;                                                                         # Return to operating system
    my $r = assemble();
    ok $r =~ m(( 0000){3} 0003)i;                                                 # Expected file number
    ok $r =~ m(( 0000){4})i;                                                      # Expected file number


=head2 localData()

Map local data


=head2 LocalData::start($local)

Start a local data area on the stack

     Parameter  Description
  1  $local     Local data descriptor

=head2 LocalData::free($local)

Free a local data area on the stack

     Parameter  Description
  1  $local     Local data descriptor

=head2 LocalData::variable($local, $length, $comment)

Add a local variable

     Parameter  Description
  1  $local     Local data descriptor
  2  $length    Length of data
  3  $comment   Optional comment

=head2 LocalVariable::stack($variable)

Address a local variable on the stack

     Parameter  Description
  1  $variable  Variable

=head2 LocalData::allocate8($local, $comment)

Add an 8 byte local variable

     Parameter  Description
  1  $local     Local data descriptor
  2  $comment   Optional comment

=head2 MemoryClear($addr, $length)

Clear memory

     Parameter  Description
  1  $addr      Stack offset of buffer address
  2  $length    Stack offset of length of buffer

=head2 Read($fileDes, $addr, $length)

Read data the specified file descriptor into the specified buffer of specified length

     Parameter  Description
  1  $fileDes   Stack offset of file descriptor
  2  $addr      Stack offset of buffer address
  3  $length    Stack offset of length of buffer

=head2 ReadFile($file, $reg)

Read a file into memory returning its address and length in the named x|y|zmm* register

     Parameter  Description
  1  $file      File
  2  $reg       Register

=head2 StatSize($file)

Stat a file to get its size in rax

     Parameter  Description
  1  $file      File

B<Example:>


    Start;                                                                        # Start the program
    my $f = Rs($0);                                                               # File to stat

    StatSize($f);                                                                 # Stat the file  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    PrintOutRegisterInHex rax;
    Exit;                                                                         # Return to operating system
    my $r = assemble() =~ s( ) ()gsr;
    if ($r =~ m(rax:([0-9a-f]{16}))is)                                            # Compare file size obtained with that from fileSize()
     {is_deeply $1, sprintf("%016X", fileSize($0));
     }


=head2 assemble(%options)

Assemble the generated code

     Parameter  Description
  1  %options   Options

B<Example:>


    Start;
    PrintOutString "Hello World";
    Exit;

    ok assemble =~ m(Hello World);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲




=head1 Private Methods

=head2 label()

Create a unique label



=head1 Index


1 L<allocateMemory|/allocateMemory> - Allocate memory via mmap

2 L<assemble|/assemble> - Assemble the generated code

3 L<ClearRegisters|/ClearRegisters> - Clear registers by setting them to zero

4 L<Close|/Close> - Close a file descriptor

5 L<Comment|/Comment> - Insert a comment into the assembly code

6 L<Db|/Db> - Layout bytes in the data segment and return their label

7 L<Dbwdq|/Dbwdq> - Layout data

8 L<Dd|/Dd> - Layout double words in the data segment and return their label

9 L<Dq|/Dq> - Layout quad words in the data segment and return their label

10 L<Ds|/Ds> - Layout bytes in memory and return their label

11 L<Dw|/Dw> - Layout words in the data segment and return their label

12 L<Exit|/Exit> - Exit with the specified return code or zero if no return code supplied

13 L<For|/For> - For

14 L<Fork|/Fork> - Fork

15 L<freeMemory|/freeMemory> - Free memory via mmap

16 L<GetPid|/GetPid> - Get process identifier

17 L<GetPPid|/GetPPid> - Get parent process identifier

18 L<GetUid|/GetUid> - Get userid of current process

19 L<If|/If> - If

20 L<label|/label> - Create a unique label

21 L<localData|/localData> - Map local data

22 L<LocalData::allocate8|/LocalData::allocate8> - Add an 8 byte local variable

23 L<LocalData::free|/LocalData::free> - Free a local data area on the stack

24 L<LocalData::start|/LocalData::start> - Start a local data area on the stack

25 L<LocalData::variable|/LocalData::variable> - Add a local variable

26 L<LocalVariable::stack|/LocalVariable::stack> - Address a local variable on the stack

27 L<MemoryClear|/MemoryClear> - Clear memory

28 L<OpenRead|/OpenRead> - Open a file for read

29 L<PeekR|/PeekR> - Peek at register on stack

30 L<PopR|/PopR> - Pop registers from the stack

31 L<PrintOutMemoryInHex|/PrintOutMemoryInHex> - Print the specified number of bytes from the specified address in hex

32 L<PrintOutNl|/PrintOutNl> - Write a new line

33 L<PrintOutRaxInHex|/PrintOutRaxInHex> - Write the content of register rax to stderr in hexadecimal in big endian notation

34 L<PrintOutRaxInReverseInHex|/PrintOutRaxInReverseInHex> - Write the content of register rax to stderr in hexadecimal in little endian notation

35 L<PrintOutRegisterInHex|/PrintOutRegisterInHex> - Print any register as a hex string

36 L<PrintOutRegistersInHex|/PrintOutRegistersInHex> - Print the general purpose registers in hex

37 L<PrintOutRflagsInHex|/PrintOutRflagsInHex> - Print the flags register in hex

38 L<PrintOutRipInHex|/PrintOutRipInHex> - Print the instruction pointer in hex

39 L<PrintOutString|/PrintOutString> - One: Write a constant string to sysout.

40 L<PushR|/PushR> - Push registers onto the stack

41 L<Rb|/Rb> - Layout bytes in the data segment and return their label

42 L<Rbwdq|/Rbwdq> - Layout data

43 L<Rd|/Rd> - Layout double words in the data segment and return their label

44 L<Read|/Read> - Read data the specified file descriptor into the specified buffer of specified length

45 L<ReadFile|/ReadFile> - Read a file into memory returning its address and length in the named x|y|zmm* register

46 L<ReadFileIntoMemory|/ReadFileIntoMemory> - Read a file into memory using mmap

47 L<readTimeStampCounter|/readTimeStampCounter> - Read the time stamp counter

48 L<registerSize|/registerSize> - Return the size of a register

49 L<RestoreFirstFour|/RestoreFirstFour> - Restore the first 4 parameter registers

50 L<RestoreFirstFourExceptRax|/RestoreFirstFourExceptRax> - Restore the first 4 parameter registers except rax so it can return its value

51 L<RestoreFirstSeven|/RestoreFirstSeven> - Restore the first 7 parameter registers

52 L<RestoreFirstSevenExceptRax|/RestoreFirstSevenExceptRax> - Restore the first 7 parameter registers except rax which is being used to return the result

53 L<ReverseBytesInRax|/ReverseBytesInRax> - Reverse the bytes in rax

54 L<Rq|/Rq> - Layout quad words in the data segment and return their label

55 L<Rs|/Rs> - Layout bytes in read only memory and return their label

56 L<Rw|/Rw> - Layout words in the data segment and return their label

57 L<SaveFirstFour|/SaveFirstFour> - Save the first 4 parameter registers

58 L<SaveFirstSeven|/SaveFirstSeven> - Save the first 7 parameter registers

59 L<SetLabel|/SetLabel> - Set a label in the code section

60 L<Start|/Start> - Initialize the assembler

61 L<StatSize|/StatSize> - Stat a file to get its size in rax

62 L<WaitPid|/WaitPid> - Wait for the pid in rax to complete

=head1 Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via B<cpan>:

  sudo cpan install Nasm::X86

=head1 Author

L<philiprbrenan@gmail.com|mailto:philiprbrenan@gmail.com>

L<http://www.appaapps.com|http://www.appaapps.com>

=head1 Copyright

Copyright (c) 2016-2021 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.

=cut



# Tests and documentation

sub test
 {my $p = __PACKAGE__;
  binmode($_, ":utf8") for *STDOUT, *STDERR;
  return if eval "eof(${p}::DATA)";
  my $s = eval "join('', <${p}::DATA>)";
  $@ and die $@;
  eval $s;
  $@ and die $@;
  1
 }

test unless caller;

1;
# podDocumentation
__DATA__
use Time::HiRes qw(time);
use Test::More;

my $localTest = ((caller(1))[0]//'Nasm::X86') eq "Nasm::X86";                   # Local testing mode

Test::More->builder->output("/dev/null") if $localTest;                         # Reduce number of confirmation messages during testing

$ENV{PATH} = $ENV{PATH}.":/var/isde:sde";                                       # Intel emulator

if ($^O =~ m(bsd|linux)i)                                                       # Supported systems
 {if (confirmHasCommandLineCommand(q(nasm)) and                                 # Network assembler
      confirmHasCommandLineCommand(q(sde64)))                                   # Intel emulator
   {plan tests => 26;
   }
  else
   {plan skip_all =>qq(Nasm or Intel 64 emulator not available);
   }
 }
else
 {plan skip_all =>qq(Not supported on: $^O);
 }

my $start = time;                                                               # Tests

#goto latest;

if (1) {                                                                        #TExit #TPrintOutString #Tassemble #TStart
  Start;
  PrintOutString "Hello World";
  Exit;
  ok assemble =~ m(Hello World);
 }

if (1) {                                                                        #TMov #TComment #TRs #TPrintOutNl
  Start;
  Comment "Print a string from memory";
  my $s = "Hello World";
  my $m = Rs($s);
  Mov rsi, $m;
  PrintOutString rsi, length($s);
  Exit;
  ok assemble =~ m(Hello World);
 }

if (1) {                                                                        #TPrintOutRaxInHex #TXor
  Start;
  my $q = Rs('abababab');
  Mov(rax, "[$q]");
  PrintOutString "rax: ";
  PrintOutRaxInHex;
  PrintOutNl;
  Xor rax, rax;
  PrintOutString "rax: ";
  PrintOutRaxInHex;
  PrintOutNl;
  Exit;
  ok assemble() =~ m(rax: 6261 6261 6261 6261.*rax: 0000 0000 0000 0000)s;
 }

if (1) {                                                                        #TPrintOutRegistersInHex #TLea
  Start;
  my $q = Rs('abababab');
  Mov(rax, 1);
  Mov(rbx, 2);
  Mov(rcx, 3);
  Mov(rdx, 4);
  Mov(r8,  5);
  Lea r9,  "[rax+rbx]";
  PrintOutRegistersInHex;
  Exit;
  my $r = assemble();
  ok $r =~ m( r8: 0000 0000 0000 0005.* r9: 0000 0000 0000 0003.*rax: 0000 0000 0000 0001)s;
  ok $r =~ m(rbx: 0000 0000 0000 0002.*rcx: 0000 0000 0000 0003.*rdx: 0000 0000 0000 0004)s;
 }

if (1) {                                                                        #TVmovdqu32 #TVprolq  #TDs
  Start;
  my $q = Rs('a'..'z');
  my $d = Ds('0'x64);                                                           # Output area
  Vmovdqu32(xmm0, "[$q]");                                                      # Load
  Vprolq   (xmm0,   xmm0, 32);                                                  # Rotate double words in quad words
  Vmovdqu32("[$d]", xmm0);                                                      # Save
  PrintOutString($d, 16);
  Exit;
  ok assemble() =~ m(efghabcdmnopijkl)s;
 }

if (1) {
  Start;
  my $q = Rs(('a'..'p')x2);
  my $d = Ds('0'x64);
  Vmovdqu32(ymm0, "[$q]");
  Vprolq   (ymm0,   ymm0, 32);
  Vmovdqu32("[$d]", ymm0);
  PrintOutString($d, 32);
  Exit;
  ok assemble() =~ m(efghabcdmnopijklefghabcdmnopijkl)s;
 }

if (1) {                                                                        #TPopR #TVmovdqu64
  Start;
  my $q = Rs(('a'..'p')x4);
  my $d = Ds('0'x128);
  Vmovdqu32(zmm0, "[$q]");
  Vprolq   (zmm0,   zmm0, 32);
  Vmovdqu32("[$d]", zmm0);
  PrintOutString($d, 64);
  Sub rsp, 64;
  Vmovdqu64 "[rsp]", zmm0;
  PopR rax;
  PrintOutRaxInHex;
  Exit;
  ok assemble() =~ m(efghabcdmnopijklefghabcdmnopijklefghabcdmnopijklefghabcdmnopijkl)s;
 }

if (1) {                                                                        #TPrintOutRegisterInHex
  Start;
  my $q = Rs(('a'..'p')x4);
  Mov r8,"[$q]";
  PrintOutRegisterInHex r8;
  Exit;
  ok assemble() =~ m(r8: 6867 6665 6463 6261)s;
 }

if (1) {                                                                        #TVmovdqu8
  Start;
  my $q = Rs('a'..'p');
  Vmovdqu8 xmm0, "[$q]";
  PrintOutRegisterInHex xmm0;
  Exit;
  ok assemble() =~ m(xmm0: 706F 6E6D 6C6B 6A69   6867 6665 6463 6261)s;
 }

if (1) {
  Start;
  my $q = Rs('a'..'p', 'A'..'P', );
  Vmovdqu8 ymm0, "[$q]";
  PrintOutRegisterInHex ymm0;
  Exit;
  ok assemble() =~ m(ymm0: 504F 4E4D 4C4B 4A49   4847 4645 4443 4241   706F 6E6D 6C6B 6A69   6867 6665 6463 6261)s;
 }

if (1) {
  Start;
  my $q = Rs(('a'..'p', 'A'..'P') x 2);
  Vmovdqu8 zmm0, "[$q]";
  PrintOutRegisterInHex zmm0;
  Exit;
  ok assemble() =~ m(zmm0: 504F 4E4D 4C4B 4A49   4847 4645 4443 4241   706F 6E6D 6C6B 6A69   6867 6665 6463 6261   504F 4E4D 4C4B 4A49   4847 4645 4443 4241   706F 6E6D 6C6B 6A69   6867 6665 6463 6261)s;
 }

if (1) {                                                                        #TallocateMemory #TfreeMemory
  Start;
  my $N = 2048;
  my $n = Rq($N);
  my $q = Rs('a'..'p');
  allocateMemory "[$n]";
  PrintOutRegisterInHex rax;
  Vmovdqu8 xmm0, "[$q]";
  Vmovdqu8 "[rax]", xmm0;
  PrintOutString rax,16;
  PrintOutNl;

  Mov rbx, rax;
  freeMemory rbx, "[$n]";
  PrintOutRegisterInHex rax;
  Vmovdqu8 "[rbx]", xmm0;
  Exit;
  ok assemble() =~ m(abcdefghijklmnop)s;
 }

if (1) {                                                                        #TreadTimeStampCounter
  Start;
  for(1..10)
   {readTimeStampCounter;
    PrintOutRegisterInHex rax;
   }
  Exit;
  my @s = split /\n/, assemble();
  my @S = sort @s;
  is_deeply \@s, \@S;
 }

if (1) {                                                                        #TIf
  Start;
  Mov rax, 0;
  Test rax,rax;
  If
   {PrintOutRegisterInHex rax;
   } sub
   {PrintOutRegisterInHex rbx;
   };
  Mov rax, 1;
  Test rax,rax;
  If
   {PrintOutRegisterInHex rcx;
   } sub
   {PrintOutRegisterInHex rdx;
   };
  Exit;
  ok assemble() =~ m(rbx.*rcx)s;
 }

if (1) {                                                                        #TFork #TGetPid #TGetPPid #TWaitPid
  Start;                                                                        # Start the program
  Fork;                                                                         # Fork

  Test rax,rax;
  If                                                                            # Parent
   {Mov rbx, rax;
    WaitPid;
    PrintOutRegisterInHex rax;
    PrintOutRegisterInHex rbx;
    GetPid;                                                                     # Pid of parent as seen in parent
    Mov rcx,rax;
    PrintOutRegisterInHex rcx;
   }
  sub                                                                           # Child
   {Mov r8,rax;
    PrintOutRegisterInHex r8;
    GetPid;                                                                     # Child pid as seen in child
    Mov r9,rax;
    PrintOutRegisterInHex r9;
    GetPPid;                                                                    # Parent pid as seen in child
    Mov r10,rax;
    PrintOutRegisterInHex r10;
   };

  Exit;                                                                         # Return to operating system

  my $r = assemble();

#    r8: 0000 0000 0000 0000   #1 Return from fork as seen by child
#    r9: 0000 0000 0003 0C63   #2 Pid of child
#   r10: 0000 0000 0003 0C60   #3 Pid of parent from child
#   rax: 0000 0000 0003 0C63   #4 Return from fork as seen by parent
#   rbx: 0000 0000 0003 0C63   #5 Wait for child pid result
#   rcx: 0000 0000 0003 0C60   #6 Pid of parent

  if ($r =~ m(r8:( 0000){4}.*r9:(.*)\s{5,}r10:(.*)\s{5,}rax:(.*)\s{5,}rbx:(.*)\s{5,}rcx:(.*)\s{2,})s)
   {ok $2 eq $4;
    ok $2 eq $5;
    ok $3 eq $6;
    ok $2 gt $6;
   }
 }

if (1) {                                                                        #TFork #TGetPid #TGetPPid #TWaitPid
  Start;                                                                        # Start the program
  GetUid;                                                                       # Userid
  PrintOutRegisterInHex rax;
  Exit;                                                                         # Return to operating system
  my $r = assemble();
  ok $r =~ m(rax:( 0000){3});
 }

if (1) {                                                                        #TStatSize
  Start;                                                                        # Start the program
  my $f = Rs($0);                                                               # File to stat
  StatSize($f);                                                                 # Stat the file
  PrintOutRegisterInHex rax;
  Exit;                                                                         # Return to operating system
  my $r = assemble() =~ s( ) ()gsr;
  if ($r =~ m(rax:([0-9a-f]{16}))is)                                            # Compare file size obtained with that from fileSize()
   {is_deeply $1, sprintf("%016X", fileSize($0));
   }
 }

if (1) {                                                                        #TOpenRead #TClose
  Start;                                                                        # Start the program
  my $f = Rs($0);                                                               # File to stat
  OpenRead($f);                                                                 # Open file
  PrintOutRegisterInHex rax;
  Close(rax);                                                                   # Close file
  PrintOutRegisterInHex rax;
  Exit;                                                                         # Return to operating system
  my $r = assemble();
  ok $r =~ m(( 0000){3} 0003)i;                                                 # Expected file number
  ok $r =~ m(( 0000){4})i;                                                      # Expected file number
 }

if (1) {                                                                        #TreadFile
  Start;                                                                        # Start the program
  For
   {PrintOutRegisterInHex rax
   } rax, 16, 1;
  Exit;                                                                         # Return to operating system
  my $r = assemble();
  ok $r =~ m(( 0000){3} 0000)i;
  ok $r =~ m(( 0000){3} 000F)i;
 }

if (1) {                                                                        #TPrintOutRaxInReverseInHex
  Start;
  Mov rax, 0x88776655;
  Shl rax, 32;
  Or  rax, 0x44332211;
  PrintOutRaxInHex;
  PrintOutRaxInReverseInHex;
  Exit;
  ok assemble() =~ m(8877 6655 4433 2211 1122 3344 5566 7788)s;
 }

if (0) {                                                                        #TallocateMemory #TfreeMemory
  Start;
  my $N = 4096;
  my $S = registerSize rax;
  allocateMemory $N;
  PrintOutRegistersInHex;
  Mov rbx, $N;
  PushR rbx;
  PushR rax;
  MemoryClear 0, $S;
  Mov rbx, $N-5;
  PrintOutString rax, rbx;
  PrintOutMemoryInHex rax, rbx;
  Exit;
  ok assemble() =~ m(abcdefghijklmnop)s;
 }

latest:;

if (0) {                                                                        #TreadFile
  say STDERR sprintf("%x", fileSize($0));
  Start;                                                                        # Start the program
  my $f = Rs($0);                                                               # File to stat
  ReadFile($f, xmm0);                                                           # Read file
  PrintOutRegisterInHex xmm0;
  PushR xmm0;                                                                   # Stack xmm0
  PopR (rbx,rax);                                                               # Unstack xmm0=(rax,rbx)=(buffer address, length)
  PrintOutString rax, rbx;
  #PrintOutMemoryInHex rax, rbx;
  Exit;                                                                         # Return to operating system
  my $r = assemble();
#  ok $r =~ m(( 0000){3} 0003)i;                                                 # Expected file number
#  ok $r =~ m(( 0000){4})i;                                                      # Expected file number
 }

lll "Finished:", time - $start;
