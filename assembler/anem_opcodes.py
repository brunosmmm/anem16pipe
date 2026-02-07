#coding=utf-8
##@package anem_opcodes
# @brief instruction names to opcodes translation
# @since 11/15/2014
# @author Bruno Morais <brunosmmm@gmail.com>

ANEMOpcodeR      = "0000"
##Opcode by operation, type R
ANEMFuncR        = { "ADD" : "0010",
                     "SUB" : "0110",
                     "AND" : "0000",
                     "OR"  : "0001",
                     "XOR" : "1111",
                     "NOR" : "1100",
                     "SLT" : "0111",
                     "MUL" : "0011",
                     "SGT" : "1000"
                     }

ANEMOpcodeS      = "0001"
ANEMFuncS        = { "SHL"  : "0010",
                     "SHR"  : "0001",
                     "SAR"  : "0000",
                     "ROL"  : "1000",
                     "ROR"  : "0100"
                    }

ANEMOpcodeL      = { "LIU"  : '0100',
                     'LIL'  : '0101'
                   }

ANEMOpcodeJ      = { 'J'    : '1111',
                     'JAL'  : '1101',
                     'BZ'   : '10',
                     'BHLEQ' : '0110'
                   }

ANEMOpcodeW      = { 'SW'   : '0010',
                     'LW'   : '0011',
                     'JR'   : '1100'
                     }

ANEMOpcodeM1 = "1110"
ANEMFuncM1   =  { "LHL" : "0000",
                  "LHH" : "0001",
                  "LLL" : "0010",
                  "LLH" : "0011",
                  "AIS" : "0100",
                  "AIH" : "0101",
                  "AIL" : "0110"
                  }

ANEMFuncM3 = {    "MFHI" : "0111",
                  "MFLO" : "1000",
                  "MTHI" : "1001",
                  "MTLO" : "1010"
}

ANEMOpcodeSTK = "0111"
ANEMFuncSTK = {   "PUSH" : "0000",
                  "POP"  : "0001",
                  "SPRD" : "0010",
                  "SPWR" : "0011"
}

ANEMOpcodeADDI = "1011"

ANEMFuncSYSCALL = "1011"
ANEMFuncM4      = "1100"
ANEMSubM4 = {  "RETI"  : "0000",
               "EI"    : "0001",
               "DI"    : "0010",
               "MFEPC" : "0011",
               "MFECA" : "0100",
               "MTEPC" : "0101"
}

##@todo bring floating point support although we do not have a FPU now
"""
ANEMOpcodeF      = { "FADD"   :  "0010",
                     'FADDP'  :  "0010",
                     'FSUB'   :  "0010",
                     'FSUBP'  :  '0010',
                     'FSUBR'  :  '0010',
                     'FSUBRP' :  '0010',
                     'FMUL'   :  '0010',
                     'FMULP'  :  '0010',
                     'FDIV'   :  '0010',
                     'FDIVP'  :  '0010',
                     'FDIVR'  :  '0010',
                     'FDIVRP' :  '0010',
                     'FABS'   :  '0010',
                     'FCHS'   :  '0010',
                     'FSIN'   :  '0011',
                     'FSINP'  :  '0011',
                     'FCOS'   :  '0011',
                     'FCOSP'  :  '0011',
                     'FTAN'   :  '0011',
                     'FTANP'  :  '0011',
                     'FASIN'  :  '0011',
                     'FASINP' :  '0011',
                     'FACOS'  :  '0011',
                     'FACOSP' :  '0011'
                    }
"""
