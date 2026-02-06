##@package anem_regex
# @brief Regular expressions for interpreting input
# @since 11/15/2014

import re

##pseudo-instruction regexes
NOP  = re.compile(r"NOP\s*$")
LIW  = re.compile(r"LIW\s+\$([0-9]{1,2}),\s*((0[xX][a-fA-F0-9]+)|([0-9]+))\s*$")
LIWb = re.compile(r"LIW\s+\$(\d{1,2}),\s*(0[bB][01]+)")
LIWh = re.compile(r"LIW\s+\$(\d{1,2}),\s*(0[xX][a-fA-F0-9]+)")
LIWd = re.compile(r"LIW\s+\$(\d{1,2}),\s*([+-]?\d+)")
#move $r1 -> $r2 pseudoinstruction
MOVE = re.compile(r"MOVE\s+\$(\d{1,2}),\s*\$(\d{1,2})")
#load HI & LO pseudoinstructions
L_HILOd = re.compile(r"(LHI|LLO)\s+(\d+)")
L_HILOh = re.compile(r"(LHI|LLO)\s+(0[xX][a-fA-F0-9]+)")
#multiply & add imm pseudoinstruction
MADD = re.compile(r"MADD\s+\$(\d{1,2}),\s*\$(\d{1,2}),\s*([+-]?\d+)")

##Constants
CONST   = re.compile(r"^\..*")
CONSTVb = re.compile(r"\.CONSTANT\s+(\w+)\s*=\s*(0[bB][01]+)")
CONSTVh = re.compile(r"\.CONSTANT\s+(\w+)\s*=\s*(0[xX][a-fA-F0-9]+)")
CONSTVd = re.compile(r"\.CONSTANT\s+(\w+)\s*=\s*(\d+)")
ADDRh   = re.compile(r"\.ADDRESS\s+(0[xX][a-fA-F0-9]+)")
ADDRd   = re.compile(r"\.ADDRESS\s+(\d+)")

##Comments
COMM = re.compile(r"--.*$")

##Instruction types
typeR   = re.compile(r"^\s*(A[DN]D|S(UB|LT|GT)|[XN]?OR|MUL)\s+\$(\d{1,2}),\s*\$(\d{1,2})\s*$")
typeS   = re.compile(r"^\s*((SH|RO)[RL]|SAR)\s+\$(\d{1,2}),\s*\$(\d{1,2})\s*$")
typeJ   = re.compile(r"^\s*(J(AL)?)\s+(%?\w+%?)\s*$")
typeHAB = re.compile(r"^\s*HAB\s*$")
typeL   = re.compile(r"^\s*(LI[LU])\s+\$(\d{1,2}),\s*([+-]?\d+|0[xX][a-fA-F0-9]+|(%\w+%[UL]?))\s*$")
typeW   = re.compile(r"^\s*([SL]W)\s+\$(\d{1,2}),\s*([+-]?\d+)\(\$(\d{1,2})\)\s*$")
typeBZ  = re.compile(r"^\s*(BZ)\s+(%?\w+%?),([TNX])\s*$")
typeJR  = re.compile(r"^\s*(JR)\s+\$(\d{1,2})\s*$")
typeF   = re.compile(r"^\s*(F((ADD|SUBR?|MUL|DIVR?|A?(SIN|COS)|TAN)P?)|AB(S|P))\s*$")
typeFx  = re.compile(r"^\s*(F((M|S)(LD|STP?)|SX))\s+\$(\d{1,3})\s*$")
typeM1   = re.compile(r"^\s*(LHL|LHH|LLL|LLH|AIS|AIH|AIL)\s+([+-]?\d+)\s*")
typeM3   = re.compile(r"^\s*(MFHI|MFLO|MTHI|MTLO)\s+\$(\d{1,2})\s*")
typeM2  = re.compile(r"^\s*(BHLEQ)\s+(%?\w+%?)\s*$")
typeSTK = re.compile(r"^\s*(PUSH|POP|SPRD|SPWR)\s+\$(\d{1,2})\s*$")
typeADDI = re.compile(r"^\s*ADDI\s+\$(\d{1,2})\s*,\s*([+-]?\d+)\s*$")
