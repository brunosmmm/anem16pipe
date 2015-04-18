##@package anem_regex
# @brief Regular expressions for interpreting input
# @since 11/15/2014

import re

##pseudo-instruction regexes
NOP  = re.compile(r"NOP\s*$")
LIW  = re.compile(r"LIW\s+\$([0-9]{1,2}),\s*((0[xX][a-fA-F0-9]+)|([0-9]+))\s*$")
LIWb = re.compile(r"LIW\s+\$(\d{1,2}),\s*(0[bB][01]+)")
LIWh = re.compile(r"LIW\s+\$(\d{1,2}),\s*(0[xX][a-fA-F0-9]+)")
LIWd = re.compile(r"LIW\s+\$(\d{1,2}),\s*(\d+)")

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
typeR   = re.compile(r"^\s*(A[DN]D|S(UB|LT)|[XN]?OR)\s+\$(\d{1,2}),\s*\$(\d{1,2})\s*$")
typeS   = re.compile(r"^\s*((SH|RO)[RL]|SAR)\s+\$(\d{1,2}),\s*(\d+)\s*$")
typeJ   = re.compile(r"^\s*(J(AL)?)\s+(%?\w+%?)\s*$")
typeHAB = re.compile(r"^\s*HAB\s*$")
typeL   = re.compile(r"^\s*(LI[LU])\s+\$(\d{1,2}),\s*(\d+|(%\w+%[UL]?))\s*$")
typeW   = re.compile(r"^\s*([SL]W)\s+\$(\d{1,2}),([+-]?\d+)\(\$(\d{1,2})\)\s*$")
typeBZ  = re.compile(r"^\s*(BZ)\s+(%?\w+%?),([tnx])\s*$")
typeJR  = re.compile(r"^\s*(JR)\s+\$(\d{1,2})\s*$")
typeF   = re.compile(r"^\s*(F((ADD|SUBR?|MUL|DIVR?|A?(SIN|COS)|TAN)P?)|AB(S|P))\s*$")
typeFx  = re.compile(r"^\s*(F((M|S)(LD|STP?)|SX))\s+\$(\d{1,3})\s*$")
typeMFHI = re.compile(r"^\s*MFHI\s+\$(\d{1,2})\s*")
typeMFLO = re.compile(r"^\s*MFLO\s+\$(\d{1,2})\s*")
typeM1   = re.compile(r"^\s*(LHL|LHH|LLL|LLH|AIS)\s+(\d+)\s*")
