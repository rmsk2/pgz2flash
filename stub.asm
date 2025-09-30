* = $0300
.cpu "w65c02"

jmp main

.include "api.asm"
.include "zeropage.asm"
.include "arith16.asm"
.include "setup.asm"
.include "clut.asm"
.include "khelp.asm"
.include "txtio.asm"

TXT_HELP  .text " This is the pgz2flash stub. Unfortunately your BASIC program can not be run"
TXT_HELP2 .text "       without your help. First press any key to return to BASIC."
TXT_HELP3 .text "       When in BASIC type xgo and after that press the RETURN key."
BASIC     .text "basic", $00

main
    jsr mmuSetup
    jsr clut.init
    jsr txtio.init80x60
    
    lda # TXT_WHITE << 4 | TXT_BLUE
    sta CURSOR_STATE.col
    jsr txtio.clear

    jsr txtio.newLine
    jsr txtio.newLine
    jsr txtio.newLine
    jsr txtio.newLine
    jsr txtio.newLine
    jsr txtio.newLine

    #printString TXT_HELP, len(TXT_HELP)
    jsr txtio.newLine
    jsr txtio.newLine
    #printString TXT_HELP2, len(TXT_HELP2)

    jsr txtio.newLine
    jsr txtio.newLine
    #printString TXT_HELP3, len(TXT_HELP3)

    jsr initEvents
    jsr waitForKey

    #load16BitImmediate BASIC, kernel.args.buf
    jsr kernel.RunNamed

    ; we should never get here ... .
    jsr sys64738
    rts