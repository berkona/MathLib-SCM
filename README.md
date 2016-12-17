# MathLib-SCM
A small math and PRNG library for single-cycle MIPS
# Usage
Use "jal" to access all functions.  See comment strings above functions for specific usage information.
## MARS &ge; 4.2
Use ".include" directive.  It effectively copies all code of a file into the current file at assemble time.
## MARS &lt 4.2
Copy full text of the lib.asm file into your project file. 
# Disclaimer
I have attempted to outline the edge cases of the functions below that I know of, but I make no guarantee that I have described all edge cases or that the code will work on your system.
# License & Copyright
Copyright 2016 Jon Monroe, released under the MIT License.
