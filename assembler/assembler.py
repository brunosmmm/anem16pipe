#coding=utf-8
##@file assembler.py
# @brief assembler for ANEM translated from ruby version
# @author Bruno Morais <brunosmmm@gmail.com>
# @since 11/14/2014

import re
import sys
import anem_opcodes

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
typeR   = re.compile("^\s*(A[DN]D|S(UB|LT)|[XN]?OR)\s+\$(\d{1,2}),\s*\$(\d{1,2})\s*$")
typeS   = re.compile("^\s*((SH|RO)[RL]|SAR)\s+\$(\d{1,2}),\s*(\d+)\s*$")
typeJ   = re.compile("^\s*(J(AL)?)\s+(%?\w+%?)\s*$")
typeHAB = re.compile("^\s*HAB\s*$")
typeL   = re.compile("^\s*(LI[LU])\s+\$(\d{1,2}),\s*(\d+|(%\w+%[UL]?))\s*$")
typeW   = re.compile("^\s*([SL]W)\s+\$(\d{1,2}),([+-]?\d+)\(\$(\d{1,2})\)\s*$")
typeBEQ = re.compile("^\s*(BEQ)\s+\$(\d{1,2}),\s*\$(\d{1,2}),(%?\w+%?)\s*$")
typeJR  = re.compile("^\s*(JR)\s+\$(\d{1,2})\s*$")
typeF   = re.compile("^\s*(F((ADD|SUBR?|MUL|DIVR?|A?(SIN|COS)|TAN)P?)|AB(S|P))\s*$")
typeFx  = re.compile("^\s*(F((M|S)(LD|STP?)|SX))\s+\$(\d{1,3})\s*$")

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

##Message type output color
MsgTypeOut = {AsmMsgType.AsmMsgError   : MsgColors.red,
              AsmMsgType.AsmMsgWarning : MsgColors.yellow,
              AsmMsgType.AsmMsgInfo    : MsgColors.nocolor,
              AsmMsgType.AsmMsgDebug   : MsgColors.cyan
              }

##Colored console output
def colorize(text, color):
    if color == MsgColors.nocolor:
        return text
    else:
        return color + text + MsgColors.end

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
    #@param msgType type of output
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

    f = open(fileName+".asm",'r')
    lines = f.readlines()
    f.close()
    
    nline = 0
    output = []
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
            output.append(label+':')

        #LIW replace
        m = LIWb.match(upLine)
        if m != None:
            #binary value
            output.append([nline,"LIU %s, %d" % (m.group(1),int(m.group(2),2)/256)]) 
            output.append([nline,"LIL %s, %d" % (m.group(1),int(m.group(2),2)%256)])
            output.append([nline,"ADD $0,$0"]) #this is a NOP after LIL
            ##@todo verify this, was a hack for non-pipelined version
            
            continue

        m = LIWh.match(upLine)
        if m != None:
            #hexadecimal
            output.append([nline,"LIU %s, %d" % (m.group(1),int(m.group(2),16)/256)]) 
            output.append([nline,"LIL %s, %d" % (m.group(1),int(m.group(2),16)%256)])
            output.append([nline,"ADD $0,$0"])
            
            continue
            
        m = LIWd.match(upLine)
        if m != None:
            #decimal
            output.append([nline,"LIU %s, %d" % (m.group(1),int(m.group(2))/256)]) 
            output.append([nline,"LIL %s, %d" % (m.group(1),int(m.group(2))%256)])
            output.append([nline,"ADD $0,$0"])

            continue

        if upLine != '':
            output.append([nline,upLine])

    #writes .clean file
    outFile = open(fileName+".clean","w")
    for nline,line in output:
        outFile.write(str(nline)+'\t'+line+'\n')
    outFile.close()

    asm.Message("%s.clean written" % fileName,AsmMsgType.AsmMsgInfo)

    #indexer
    index = 0
    labels = {}
    code = []
    iline = ''
    for nline,line in output:
        
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
                labels[m.group(1)] = int(m.group(2),2) 
                continue

            m = CONSTVh.match(line)
            if m != None:
                labels[m.group(1)] = int(m.group(2),16)
                continue

            m = CONSTVd.match(line)
            if m != None:
                labels[m.group(1)] = int(m.group(2))
                continue

            asm.Message("Line %d: Invalid directive: %s" % (nline,line),AsmMsgType.AsmMsgError)
        else:
            label = None
            try:
                label,iline = line.split(':')
            except:
                iline = line

            if label != None:
                labels[label.strip()] = index

            if iline != '':
                code.append([index,nline,iline.strip()])
                index = index + 1

    outFile = open(fileName+".ind","w")

    outFile.write(".LABELS\n")
    for label in labels.keys():
        outFile.write(label+'\t'+str(labels[label])+'\n')
    

    outFile.write(".CODE\n")
    for index,nline,iline in code:
        outFile.write(str(index)+'\t'+str(nline)+'\t'+iline+'\n')

    outFile.close()

    asm.Message("%s.ind written" % fileName, AsmMsgType.AsmMsgInfo)

    #assembler
    
