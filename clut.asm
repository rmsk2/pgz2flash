saveIo .macro
    lda $01
    pha
.endmacro

setIo .macro page
    lda #\page
    sta $01
.endmacro

restoreIo .macro
    pla
    sta $01
.endmacro


TXT_BLACK = 0
TXT_WHITE = 1
TXT_BLUE = 2
TXT_GREEN = 3

clut .namespace

TXT_LUT_FORE_GROUND_BASE = $D800
TXT_LUT_BACK_GROUND_BASE = $D840



setTxtColInt .macro colNum, red, green, blue, alpha
    lda #\blue
    sta TXT_LUT_FORE_GROUND_BASE + ((\colNum & 15) * 4)
    sta TXT_LUT_BACK_GROUND_BASE + ((\colNum & 15) * 4)
    lda #\green
    sta TXT_LUT_FORE_GROUND_BASE + ((\colNum & 15) * 4) + 1
    sta TXT_LUT_BACK_GROUND_BASE + ((\colNum & 15) * 4) + 1
    lda #\red
    sta TXT_LUT_FORE_GROUND_BASE + ((\colNum & 15) * 4) + 2
    sta TXT_LUT_BACK_GROUND_BASE + ((\colNum & 15) * 4) + 2
    lda #\alpha
    sta TXT_LUT_FORE_GROUND_BASE + ((\colNum & 15) * 4) + 3
    sta TXT_LUT_BACK_GROUND_BASE + ((\colNum & 15) * 4) + 3
.endmacro


setTxtCol .macro colNum, red, green, blue, alpha
    #saveIo
    #setIo 0
    #setTxtColInt \colNum, \red, \green, \blue, \alpha
    #restoreIo
.endmacro


init
    #saveIo
    
    #setIo 0
    #setTxtColInt TXT_BLACK,  $00, $00, $00, $FF
    #setTxtColInt TXT_WHITE,  $FF, $FF, $FF, $FF
    #setTxtColInt TXT_BLUE,  $00, $00, $FF, $FF
    #setTxtColInt TXT_GREEN,  $00, $FF, $00, $FF
    ; #setTxtColInt 3,  $00, $CF, $00, $FF
    ; #setTxtColInt 4,  $00, $BF, $00, $FF
    ; #setTxtColInt 5,  $00, $AF, $00, $FF
    ; #setTxtColInt 6,  $00, $9F, $00, $FF
    ; #setTxtColInt 7,  $00, $8F, $00, $FF
    ; #setTxtColInt 8,  $00, $7F, $00, $FF
    ; #setTxtColInt 9,  $00, $6F, $00, $FF
    ; #setTxtColInt 10, $00, $5F, $00, $FF
    ; #setTxtColInt 11, $00, $4F, $00, $FF
    ; #setTxtColInt 12, $00, $3F, $00, $FF
    ; #setTxtColInt 13, $00, $2F, $00, $FF
    ; #setTxtColInt 14, $00, $1F, $00, $FF
    ; #setTxtColInt 15, $00, $0F, $00, $FF
    
    #restoreIo
    rts

.endnamespace