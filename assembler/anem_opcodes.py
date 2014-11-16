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
                     "SLT" : "0111"
                     }

ANEMOpcodeS      = "0001"
ANEMFuncS        = { "SHL"  : "0010",
                     "SHR"  : "0001",
                     "SAR"  : "0000",
                     "ROL"  : "1000",
                     "ROR"  : "0100"
                    }

ANEMOpcodeL      = { "LIU"  : '1100',
                     'LIL'  : '1101'
                   }

ANEMOpcodeJ      = { 'J'    : '1000',
                     'JAL'  : '1001'
                   }

ANEMOpcodeW      = { 'SW'   : '0100',
                     'LW'   : '0101',
                     'BEQ'  : '0110',
                     'JR'   : '0111'
                     }

##@todo bring floating point support although we do not have a FPU now
"""
ANEMOpcodeF      = { "FADD"   : "0010",
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
