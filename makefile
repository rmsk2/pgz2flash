BINARY=loader
GOLOADER=loader.go
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

$(TOOL): pgz2flash.go $(GOLOADER)
	go build

binaries: $(BIN_WIN_AMD64) $(BIN_MAC_AMD64) $(BIN_MAC_ARM64) $(BIN_LIN_AMD64) $(BIN_LIN_ARM64)

$(BIN_WIN_AMD64): pgz2flash.go $(GOLOADER)
	GOOS=windows GOARCH=amd64 go build -o $(BIN_WIN_AMD64)

$(BIN_MAC_AMD64): pgz2flash.go $(GOLOADER)
	GOOS=darwin GOARCH=amd64  go build -o $(BIN_MAC_AMD64)

$(BIN_MAC_ARM64): pgz2flash.go $(GOLOADER)
	GOOS=darwin GOARCH=arm64  go build -o $(BIN_MAC_ARM64)

$(BIN_LIN_AMD64): pgz2flash.go $(GOLOADER)
	GOOS=linux GOARCH=amd64  go build -o $(BIN_LIN_AMD64)

$(BIN_LIN_ARM64): pgz2flash.go $(GOLOADER)
	GOOS=linux GOARCH=arm64  go build -o $(BIN_LIN_ARM64)


$(GOLOADER): $(BINARY)
	$(PYTHON) bin2go.py $(BINARY) > $(GOLOADER)

$(BINARY): *.asm
	64tass -l $(LABELS) --nostart -o $(BINARY) main.asm	

clean: 
	$(RM) $(FORCE) $(BINARY)
	$(RM) $(FORCE) $(LABELS)
	$(RM) $(FORCE) $(TOOL)
	$(RM) $(FORCE) $(GOLOADER)
	$(RM) $(FORCE) $(BIN_WIN_AMD64)
	$(RM) $(FORCE) $(BIN_MAC_AMD64)
	$(RM) $(FORCE) $(BIN_MAC_ARM64)
	$(RM) $(FORCE) $(BIN_LIN_AMD64)
	$(RM) $(FORCE) $(BIN_LIN_ARM64)
