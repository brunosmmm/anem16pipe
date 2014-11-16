#coding=utf-8
##@file assembler.py
# @brief assembler for ANEM translated from ruby version
# @author Bruno Morais <brunosmmm@gmail.com>
# @since 11/14/2014

import re
import sys
from anem_opcodes import *
from anem_regex import *


##Verbose level
class AsmMsgType:
    
    AsmMsgError   = 0
    AsmMsgWarning = 1
    AsmMsgInfo    = 2
    AsmMsgDebug   = 3

class MsgColors:

    red = '\033[31m'
    green = '\033[32m'
    yellow = '\033[33m'
    cyan = '\033[36m'
    nocolor = ''
    end = '\033[0m'

##Message type self.CleanOut color
MsgTypeOut = {AsmMsgType.AsmMsgError   : MsgColors.red,
              AsmMsgType.AsmMsgWarning : MsgColors.yellow,
              AsmMsgType.AsmMsgInfo    : MsgColors.nocolor,
              AsmMsgType.AsmMsgDebug   : MsgColors.cyan
              }

##Colored console self.CleanOut
def colorize(text, color):
    if color == MsgColors.nocolor:
        return text
    else:
        return color + text + MsgColors.end

##Make binary strings
def makeBinStr(i,size):
    
    m = re.match(r"0b([01]+)",bin(i))
    b = m.group(1)

    if len(b) < size:
        #pad
        for i in range(len(b), size):
            b = '0' + b
    elif len(b) > size:
        raise ValueError("number already bigger than desired size")

    return b


class Assembler:
    ##Error count
    AsmErrorCount = 0
    ##Warning count
    AsmWarnCount = 0
    ##Fatal error
    AsmFatalError = False
    ##verbosity
    Verbosity = 2

    ##Print out assembler messages
    #@param msg string
    #@param msgType type of self.CleanOut
    #@return fatal error occurred or not
    def Message(self,msg,msgType):

        fatal = False

        if msgType == AsmMsgType.AsmMsgError:
            self.AsmErrorCount += 1
            if self.AsmFatalError == True and self.AsmErrorCount >= 1:
                print colorize("(FATAL) ",MsgColors.red),
                fatal = True
                ##@todo get out, fatal error
            elif msgType == AsmMsgType.AsmMsgWarning:
                self.AsmWarnCount += 1
                if Verbosity < 1:
                    return False#dont print
                elif msgType == AsmMsgType.AsmMsgInfo:
                    if Verbosity < 2:
                        return False#dont print
                    elif msgType == AsmMsgType.AsmMsgDebug:
                        if Verbosity < 3:
                            return False

        print colorize(msg,MsgTypeOut[msgType])
        return fatal

    ##Output messages when done    
    def Done(self):

        print str(self.AsmErrorCount)+ \
              colorize(" error(s) ",MsgTypeOut[AsmMsgType.AsmMsgError])+ \
              str(self.AsmWarnCount)+ \
              colorize(" warning(s) ",MsgTypeOut[AsmMsgType.AsmMsgWarning])

    ##Output messages on init
    def Init(self):

        print colorize("ANEM Assembler",MsgColors.green)

    def Clean(self):
        nline = 0
        self.CleanOut = []
        for line in lines:
            nline = nline + 1
            upLine = line.upper()
            upLine = upLine.strip()
            upLine = COMM.sub('',upLine)         #Comments are ignored!
            upLine = NOP.sub("ADD $0,$0",upLine) #Substitute NOP

            label = None
            if re.match(r".*:\s+LIW.*",upLine) != None:
                #Cannot substitute LIW when there is a label
                asm.Message("Line %d: label followed by LIW" % nline,AsmMsgType.AsmMsgDebug)
                label,upLine = upLine.split(':')
                self.CleanOut.append(label+':')

            #LIW replace
            m = LIWb.match(upLine)
            if m != None:
                #binary value
                self.CleanOut.append([nline,"LIU $%s, %d" % (m.group(1),int(m.group(2),2)/256)]) 
                self.CleanOut.append([nline,"LIL $%s, %d" % (m.group(1),int(m.group(2),2)%256)])
                self.CleanOut.append([nline,"ADD $0,$0"]) #this is a NOP after LIL
                ##@todo verify this, was a hack for non-pipelined version

                continue

            m = LIWh.match(upLine)
            if m != None:
                #hexadecimal
                self.CleanOut.append([nline,"LIU $%s, %d" % (m.group(1),int(m.group(2),16)/256)]) 
                self.CleanOut.append([nline,"LIL $%s, %d" % (m.group(1),int(m.group(2),16)%256)])
                self.CleanOut.append([nline,"ADD $0,$0"])

                continue

            m = LIWd.match(upLine)
            if m != None:
                #decimal
                self.CleanOut.append([nline,"LIU $%s, %d" % (m.group(1),int(m.group(2))/256)]) 
                self.CleanOut.append([nline,"LIL $%s, %d" % (m.group(1),int(m.group(2))%256)])
                self.CleanOut.append([nline,"ADD $0,$0"])

                continue

            if upLine != '':
                self.CleanOut.append([nline,upLine])

    def Index(self):
        index = 0
        self.labels = {}
        self.code = []
        iline = ''
        for nline,line in self.CleanOut:

            #constant handling
            if CONST.match(line) != None:

                m = ADDRh.match(line)
                if m != None:
                    index = int(m.group(1),16)
                    continue

                m = ADDRd.match(line)
                if m != None:
                    index = int(m.group(1))
                    continue

                m = CONSTVb.match(line)
                if m != None:
                    self.labels[m.group(1)] = int(m.group(2),2) 
                    continue

                m = CONSTVh.match(line)
                if m != None:
                    self.labels[m.group(1)] = int(m.group(2),16)
                    continue

                m = CONSTVd.match(line)
                if m != None:
                    self.labels[m.group(1)] = int(m.group(2))
                    continue

                asm.Message("Line %d: Invalid directive: %s" % (nline,line),AsmMsgType.AsmMsgError)
            else:
                label = None
                try:
                    label,iline = line.split(':')
                except:
                    iline = line

                if label != None:
                    self.labels[label.strip()] = index

                if iline != '':
                    self.code.append([index,nline,iline.strip()])
                    index = index + 1

    ##Make R type instructions
    def makeRInstr(self,func,ra,rb):
        return ANEMOpcodeR+makeBinStr(int(ra),4)+makeBinStr(int(rb),4)+ANEMFuncR[func]

    ##Make S type instructions
    def makeSInstr(self,func,ra,shamt):
        return ANEMOpcodeS+makeBinStr(int(ra),4)+makeBinStr(int(shamt),4)+ANEMFuncS[func]

    ##@todo make this right
    def makeLInstr(self,instr,ra,byte):
        
        u = re.match(r"%(\w+)%U",byte)
        l = re.match(r"%(\w+)%L",byte)
        x = re.match(r"%(\w+)%",byte)
        d = re.match(r"\d+",byte)

        if u != None:
            out = makeBinStr(int(self.labels[u.group(1)])/256,8)
        elif l != None:
            out = makeBinStr(int(self.labels[l.group(1)])%256,8)
        elif d != None:
            out = makeBinStr(int(byte),8)
        elif x != None:
            out = makeBinStr(int(self.labels[byte],8))
        else:
            raise ValueError("malformed instruction")

        return ANEMOpcodeL[instr]+makeBinStr(int(ra),4)+out

    def makeJInstr(self,jtype,addr):

        d = re.match(r"[0-9]+",addr)
        l = re.match(r"%(\w+)%",addr)

        if d != None:
            out = makeBinStr(int(addr),12)
        elif l != None:
            out = makeBinStr(int(self.labels[l.group(1)]),12)
        else:
            raise ValueError("malformed instruction")

        return ANEMOpcodeJ[jtype]+out

    def makeWInstr(self,instr,ra,rb,offset,index):
        
        o = re.match(r"%(\w+)%",offset)
        d = re.match(r"\d+",offset)
        if d != None:
            out = makeBinStr(int(offset),4)
        elif o != None:
            off_dec = int(self.labels[o.group(1)])-1-int(index)
            out = makeBinStr(off_dec,4)

            self.Message("BEQ jumps, %d -> %d bin" % (off_dec,out), AsmMsgType.AsmMsgDebug)
            if off_dec > 7 or off_dec < -8:
                #impossible BEQ
                self.Message("INST %s: BEQ cannot jump to intended place. OFFSET = %d" % (index,off_dec), AsmMsgType.AsmMsgWarning)
        
        else:
            raise ValueError("BEQ offset error")
        
        return ANEMOpcodeW[instr]+makeBinStr(int(ra),4)+makeBinStr(int(rb),4)+out
    

    def Assemble(self):
        
        self.binCode = []
        for index,nline,line in self.code:
            
            m = typeR.match(line)
            if m != None:
                self.binCode.append([makeBinStr(int(index),16),self.makeRInstr(m.group(1),m.group(3),m.group(4))])
                continue
            
            m = typeS.match(line)
            if m != None:
                self.binCode.append([makeBinStr(int(index),16),self.makeSInstr(m.group(1),m.group(3),m.group(4))])
                continue

            m = typeL.match(line)
            if m != None:
                self.binCode.append([makeBinStr(int(index),16),self.makeLInstr(m.group(1),m.group(2),m.group(3))])
                continue

            m = typeJ.match(line)
            if m != None:
                self.binCode.append([makeBinStr(int(index),16),self.makeJInstr(m.group(1),m.group(3))])
                continue

            m = typeW.match(line)
            if m != None:
                self.binCode.append([makeBinStr(int(index),16),self.makeWInstr(m.group(1),m.group(2),m.group(4),m.group(3),index)])
                continue

            m = typeBEQ.match(line)
            if m != None:
                self.binCode.append([makeBinStr(int(index),16),self.makeWInstr(m.group(1),m.group(2),m.group(3),m.group(4),index)])
                continue
            
            m = typeJR.match(line)
            if m != None:
                self.binCode.append([makeBinStr(int(index),16),self.makeWInstr(m.group(1),m.group(2),'0','0',index)])
                continue
                
            m = typeHAB.match(line)
            if m != None:
                self.binCode.append([makeBinStr(int(index),16),"1111000000000000"])
                continue
            ##@todo make floating point supported
            #m = typeF.match(line)
            
            self.Message("Line %d: unsupported or malformed instruction" % nline, AsmMsgType.AsmMsgError)

##program body
if __name__ == "__main__":

    asm = Assembler()

    asm.Init()
    
    try:
        fileName = sys.argv[1]
    except:
        AsmFatalError = True
        asm.Message("Error: no filename specified",AsmMsgType.AsmMsgError)
        exit(1)
            
    #load program

    f = open(fileName+".asm",'r')
    lines = f.readlines()
    f.close()
    
    #clean

    asm.Clean()

    #writes .clean file
    outFile = open(fileName+".clean","w")
    for nline,line in asm.CleanOut:
        outFile.write(str(nline)+'\t'+line+'\n')
    outFile.close()

    asm.Message("%s.clean written" % fileName,AsmMsgType.AsmMsgInfo)

    #indexer
    asm.Index()

    outFile = open(fileName+".ind","w")

    outFile.write(".LABELS\n")
    for label in asm.labels.keys():
        outFile.write(label+'\t'+str(asm.labels[label])+'\n')
    

    outFile.write(".CODE\n")
    for index,nline,iline in asm.code:
        outFile.write(str(index)+'\t'+str(nline)+'\t'+iline+'\n')

    outFile.close()

    asm.Message("%s.ind written" % fileName, AsmMsgType.AsmMsgInfo)

    #assembler
    asm.Assemble()

    outFile = open(fileName+".bin","w")

    for index,instruction in asm.binCode:
        outFile.write(index+'\t'+instruction+'\n')

    outFile.close()

    asm.Message("%s.bin written" % fileName, AsmMsgType.AsmMsgInfo)

    ##@todo convert to hex procedure