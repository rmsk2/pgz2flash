* = $A000
.cpu "w65c02"

LOAD_ADDRESS   = $A000
NUM_8K_BLOCKS  = 1

; This is the kernel header. It must begin at LOAD_ADDRESS
KUPHeader
.byte $F2                                  ; signature
.byte $56                                  ; signature
; ******************
; This value has to be rewritten by the tool on the PC side
; ******************
ADDR_NUM_BLOCKS
.byte NUM_8K_BLOCKS                        ; length of program in consecutive 8K flash blocks
.byte LOAD_ADDRESS / $2000                 ; block in 16 bit address space to which the first block is mapped
.word loader                               ; start address of program
.byte $01, $00, $00, $00                   ; reserved. All examples I looked at had a $01 in the first position
; ******************
; These entries have to be rewritten by the tool on the PC side
; ******************
ADDR_DESCRIPTION
.text "cpytest"                            ; name of the program used for starting
.byte $00                                  ; zero termination for "snake"
.byte $00                                  ; zero termination for parameter description
.text "Loader test"                        ; Comment shown in lsf
.byte $00

PADDING_BYTES = 64
.fill PADDING_BYTES

TARGET_VECTOR = $0092;00$93
NUM_BYTES     = $94;$95
MEM_PTR1      = $9A;$9B
MEM_PTR2      = $9C;$9D
MEM_PTR3      = $9E;$9F

; --------------------------------------------------
; load16BitImmediate loads the 16 bit value given in .val into the memory location given
; by .addr 
; --------------------------------------------------
load16BitImmediate .macro  val, addr 
    lda #<\val
    sta \addr
    lda #>\val
    sta \addr+1
.endmacro

; --------------------------------------------------
; add16BitImmediate implements a 16 bit add of an immediate value to value stored at memAddr2 
; The result is stored in .memAddr2
; --------------------------------------------------
add16BitImmediate .macro  value, memAddr2 
    clc
    ; add lo bytes
    lda #<\value
    adc \memAddr2
    sta \memAddr2
    ; add hi bytes
    lda #>\value
    adc \memAddr2+1
    sta \memAddr2+1
.endmacro

Block_t .struct l, addrS, addrT, mmuS, mmuT
    numBytes   .word \l                     ; can be at most 8192
    addrSrc    .word \addrS                 ; start address in source block
    addrTgt    .word \addrT                 ; target address in target block
    mmuCtrlSrc .byte \mmuS                  ; this is an offset
    mmuCtrlTgt .byte \mmuT                  ; this is an absolute value
.endstruct

SOURCE_ADDRESS = $8000
TARGET_ADDRESS = $6000
MMU_SOURCE     = (SOURCE_ADDRESS / $2000) + 8
MMU_TARGET     = (TARGET_ADDRESS / $2000) + 8
MMU_LOADER     = (LOAD_ADDRESS / $2000) + 8


mem .namespace
; parameters in MEM_PTR1 (source), MEM_PTR2 (target) and NUM_BYTES (length)
; works only for non overlapping slices of memory
copy
    ldy #0
_copy
    ; NUM_BYTES + 1 contains the number of full blocks
    lda NUM_BYTES + 1
    beq _lastBlockOnly
_copyBlock
    lda (MEM_PTR1), y
    sta (MEM_PTR2), y
    iny
    bne _copyBlock
    dec NUM_BYTES + 1
    inc MEM_PTR1+1
    inc MEM_PTR2+1
    bra _copy

    ; Y register is zero here
_lastBlockOnly
    ; NUM_BYTES contains the number of bytes in last block
    lda NUM_BYTES
    beq _done
_loop
    lda (MEM_PTR1), y
    sta (MEM_PTR2), y
    iny
    cpy NUM_BYTES
    bne _loop
_done
    rts
.endnamespace



loader
    lda #%10110011                         ; set active and edit LUT to three and allow editing
    sta 0
    lda #%00000000                         ; enable io pages and set active page to 0
    sta 1
    ; turn cursor off
    lda #%11111110
    and $D010
    sta $D010
    ; set MEM_PTR3 to start of copy instructions
    #load16BitImmediate ADDR_INSTRUCTIONS, MEM_PTR3
_blockLoop
    ldy #Block_t.numBytes
    ; check if last entry was found. This entry has a length value of 0
    lda (MEM_PTR3), y
    bne _bytesToCopy
    iny
    lda (MEM_PTR3), y
    bne _bytesToCopy
    ; both length bytes were zero => last entry reached
    ; determine start address
    ldy #Block_t.addrSrc
    lda (MEM_PTR3), y
    sta TARGET_VECTOR
    iny
    lda (MEM_PTR3), y
    sta TARGET_VECTOR + 1
    ; set MMU registers used for copy operation to sensible defaults
    lda #4
    sta MMU_SOURCE
    lda #3
    sta MMU_TARGET
    ; we can not change MMU_CTRL as we would map out this code
    ; jmp to target address which must not be in RAM block 5, i.e. in the block where this code
    ; was mapped by the kernel
    jmp (TARGET_VECTOR)
_bytesToCopy
    ; there is data to copy
    ; copy data length
    ldy #Block_t.numBytes
    lda (MEM_PTR3), y
    sta NUM_BYTES
    iny
    lda (MEM_PTR3), y
    sta NUM_BYTES + 1
    ; copy source address
    ldy #Block_t.addrSrc
    lda (MEM_PTR3), y
    sta MEM_PTR1
    iny
    lda (MEM_PTR3), y
    sta MEM_PTR1 + 1
    ; copy target address
    ldy #Block_t.addrTgt
    lda (MEM_PTR3), y
    sta MEM_PTR2
    iny
    lda (MEM_PTR3), y
    sta MEM_PTR2 + 1
    ; bring source page into view by adding offset value
    ldy #Block_t.mmuCtrlSrc
    lda (MEM_PTR3), y
    clc
    adc MMU_LOADER
    sta MMU_SOURCE
    ; bring target page into view via absolute value
    ldy #Block_t.mmuCtrlTgt
    lda (MEM_PTR3), y
    sta MMU_TARGET
    ; perform copy
    jsr mem.copy
    ; move MEM_PTR3 to next copy instruction
    #add16BitImmediate size(Block_t), MEM_PTR3
    bra _blockLoop

; ******************
; This has to be rewritten by the tool on the PC side
; ******************
ADDR_INSTRUCTIONS .fill 767
; B1 .dstruct Block_t, 4774, $8000 + END - LOAD_ADDRESS + 1, $6300, 0, 0
; B2 .dstruct Block_t, 0, $0300, 0, 0, 0

END .byte 0