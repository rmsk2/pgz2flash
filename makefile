BINARY=loader
GOLOADER=loader.go
LABELS=labels.txt
TOOL=pgz2flash
PYTHON=python3

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

$(GOLOADER): $(BINARY)
	$(PYTHON) bin2go.py $(BINARY) > $(GOLOADER)

$(BINARY): *.asm
	64tass -l $(LABELS) --nostart -o $(BINARY) main.asm	

clean: 
	$(RM) $(FORCE) $(BINARY)
	$(RM) $(FORCE) $(LABELS)
	$(RM) $(FORCE) $(TOOL)
	$(RM) $(FORCE) $(GOLOADER)
