BINARY=loader
GOLOADER=loader.go
GOSTUB=stub.go
STUB=stub
LABELS=labels.txt
TOOL=pgz2flash
PYTHON=python3

BIN_WIN_AMD64=$(TOOL)_win_amd64.exe
BIN_MAC_AMD64=$(TOOL)_mac_amd64
BIN_MAC_ARM64=$(TOOL)_mac_arm64
BIN_LIN_AMD64=$(TOOL)_linux_amd64
BIN_LIN_ARM64=$(TOOL)_linux_arm64

RM=rm
FORCE=-f

ifdef WIN
RM=del
FORCE=
TOOL=pgz2flash.exe
PYTHON=python
endif

$(TOOL): pgz2flash.go $(GOLOADER) $(GOSTUB)
	go build

binaries: $(BIN_WIN_AMD64) $(BIN_MAC_AMD64) $(BIN_MAC_ARM64) $(BIN_LIN_AMD64) $(BIN_LIN_ARM64)

$(BIN_WIN_AMD64): pgz2flash.go $(GOLOADER) $(GOSTUB)
	GOOS=windows GOARCH=amd64 go build -o $(BIN_WIN_AMD64)

$(BIN_MAC_AMD64): pgz2flash.go $(GOLOADER) $(GOSTUB)
	GOOS=darwin GOARCH=amd64  go build -o $(BIN_MAC_AMD64)

$(BIN_MAC_ARM64): pgz2flash.go $(GOLOADER) $(GOSTUB)
	GOOS=darwin GOARCH=arm64  go build -o $(BIN_MAC_ARM64)

$(BIN_LIN_AMD64): pgz2flash.go $(GOLOADER) $(GOSTUB)
	GOOS=linux GOARCH=amd64  go build -o $(BIN_LIN_AMD64)

$(BIN_LIN_ARM64): pgz2flash.go $(GOLOADER) $(GOSTUB)
	GOOS=linux GOARCH=arm64  go build -o $(BIN_LIN_ARM64)


$(GOLOADER): $(BINARY)
	$(PYTHON) bin2go.py $(BINARY) loaderBinary > $(GOLOADER)

$(BINARY): main.asm
	64tass -l $(LABELS) --nostart -o $(BINARY) main.asm	

$(GOSTUB): $(STUB)
	$(PYTHON) bin2go.py $(STUB) stubBinary > $(GOSTUB)

$(STUB): api.asm clut.asm khelp.asm setup.asm stub.asm txtio.asm zeropage.asm
	64tass --nostart -o $(STUB) stub.asm	


clean: 
	$(RM) $(FORCE) $(BINARY)
	$(RM) $(FORCE) $(STUB)
	$(RM) $(FORCE) $(LABELS)
	$(RM) $(FORCE) $(TOOL)
	$(RM) $(FORCE) $(GOLOADER)
	$(RM) $(FORCE) $(GOSTUB)
	$(RM) $(FORCE) $(BIN_WIN_AMD64)
	$(RM) $(FORCE) $(BIN_MAC_AMD64)
	$(RM) $(FORCE) $(BIN_MAC_ARM64)
	$(RM) $(FORCE) $(BIN_LIN_AMD64)
	$(RM) $(FORCE) $(BIN_LIN_ARM64)
