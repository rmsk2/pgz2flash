RM=rm

BINARY=loader
GOLOADER=loader.go
LABELS=labels.txt
TOOL=pgz2flash
FORCE=-f

ifdef WIN
RM=del
FORCE=
endif

$(TOOL): pgz2flash.go $(GOLOADER)
	go build

$(GOLOADER): $(BINARY)
	python3 bin2go.py $(BINARY) > $(GOLOADER)

$(BINARY): *.asm
	64tass -l $(LABELS) --nostart -o $(BINARY) main.asm	

clean: 
	$(RM) $(FORCE) $(BINARY)
	$(RM) $(FORCE) $(LABELS)
	$(RM) $(FORCE) $(TOOL)
	$(RM) $(FORCE) $(GOLOADER)
