package main

import (
	"flag"
	"fmt"
	"os"
)

const (
	LoadAddress        uint = 0xA000
	DescriptionAddress uint = 0xA00A - LoadAddress
	NumBlocksAddress   uint = 0xA002 - LoadAddress
	CopyInstructions   uint = 0xA0F5 - LoadAddress
	SourceWindow       uint = 0x8000
	TargetWindow       uint = 0x6000
)

const (
	MaxCopyInstructions = 64
	BlockSize           = 8192
	MaxDocumentation    = 64 + 21
)

func getLoaderBinary() ([]byte, error) {
	return loaderBinary, nil
}

type Segment struct {
	Address uint
	Data    []byte
}

func NewSegment(a uint, d []byte) Segment {
	return Segment{
		Address: a,
		Data:    d,
	}
}

func from24BitAddress(lo, mi, hi byte) uint {
	res := (uint)(hi) * 65536
	res += (uint)(mi) * 256
	res += (uint)(lo)

	return res
}

func to24BitSegmentedAddress(addr uint) (byte, uint16) {
	mainAdr := uint16(addr & 0b1111111111111)
	blockAddr := byte(addr >> 13)

	return blockAddr, mainAdr
}

type PgzFile struct {
	StartAddress uint
	Segments     []Segment
}

func NewPgzFromFile(fileName string) (*PgzFile, error) {
	progBytes, err := os.ReadFile(fileName)
	if err != nil {
		return nil, err
	}

	if progBytes[0] != 90 {
		return nil, fmt.Errorf("wrong file type %x", progBytes[0])
	}

	res := PgzFile{
		StartAddress: 0,
		Segments:     []Segment{},
	}

	progBytes = progBytes[1:]

	for len(progBytes) != 0 {
		progBytes, err = res.readSegment(progBytes)
		if err != nil {
			return nil, err
		}
	}

	return &res, nil
}

func (p *PgzFile) readSegment(unparsedFile []byte) ([]byte, error) {
	if len(unparsedFile) < 6 {
		return nil, fmt.Errorf("invalid segment. Segment is too short")
	}

	loadAddress := from24BitAddress(unparsedFile[0], unparsedFile[1], unparsedFile[2])
	segmentLength := from24BitAddress(unparsedFile[3], unparsedFile[4], unparsedFile[5])

	if segmentLength == 0 {
		p.StartAddress = loadAddress
		return unparsedFile[6:], nil
	}

	data := unparsedFile[6:]
	if len(data) < int(segmentLength) {
		return nil, fmt.Errorf("invalid segment. length is %d but only %d bytes left", segmentLength, len(data))
	}

	p.Segments = append(p.Segments, NewSegment(loadAddress, data[:segmentLength]))

	return data[segmentLength:], nil
}

func (p *PgzFile) PrintInfo() {
	fmt.Printf("Start address: $%06X\n\n", p.StartAddress)
	fmt.Println("PGZ segments:")
	fmt.Println("=============")

	for i, j := range p.Segments {
		fmt.Printf("%02d. Load address $%06X, Length $%06X\n", i+1, j.Address, len(j.Data))
	}
}

func (p *PgzFile) CatenateSegments(loader []byte) ([]byte, map[uint]uint, int) {
	segments := make([]byte, 0)
	res := make([]byte, 0)
	index := map[uint]uint{}
	offset := uint(len(loader))

	for _, j := range p.Segments {
		index[j.Address] = offset
		segments = append(segments, j.Data...)
		offset += uint(len(j.Data))
	}

	res = append(res, loader...)
	res = append(res, segments...)
	numFullBlocks := len(res) / BlockSize
	bytesInLastBlock := len(res) % BlockSize

	if bytesInLastBlock == 0 {
		return res, index, numFullBlocks
	}

	paddingBytes := make([]byte, BlockSize-bytesInLastBlock)
	res = append(res, paddingBytes...)

	return res, index, numFullBlocks + 1
}

func addrToBytes(a uint16) []byte {
	return []byte{byte(a & 0xFF), byte(a >> 8)}
}

type copyInstruction struct {
	numBytes   uint16
	addrSrc    uint16
	addrTgt    uint16
	mmuCtrlSrc byte
	mmuCtrlTgt byte
}

func newInstruction(l uint16, as uint16, at uint16, mmuS byte, mmuT byte) copyInstruction {
	return copyInstruction{
		numBytes:   l,
		addrSrc:    as,
		addrTgt:    at,
		mmuCtrlSrc: mmuS,
		mmuCtrlTgt: mmuT,
	}
}

func (c *copyInstruction) toSlice() []byte {
	res := make([]byte, 8)
	copy(res, addrToBytes(c.numBytes))
	copy(res[2:], addrToBytes(c.addrSrc))
	copy(res[4:], addrToBytes(c.addrTgt))
	res[6] = c.mmuCtrlSrc
	res[7] = c.mmuCtrlTgt

	return res
}

func (c *copyInstruction) print() {
	fmt.Printf("Copy $%04X bytes from $%02x:%04x to $%02X:%04X\n", c.numBytes, c.mmuCtrlSrc, c.addrSrc, c.mmuCtrlTgt, c.addrTgt)
}

func (p *PgzFile) InstructionsForOneSegment(segPos int, index map[uint]uint) ([]byte, int, error) {
	instructions := []byte{}
	numInstructions := 0
	targetAddress := p.Segments[segPos].Address
	sourceAddress := index[targetAddress]
	bytesToCopy := len(p.Segments[segPos].Data)
	bytesCopied := 0

	mmuSrc, addrSrc := to24BitSegmentedAddress(sourceAddress)
	mmuTgt, addrTgt := to24BitSegmentedAddress(targetAddress)

	for bytesToCopy > 0 {
		bytesLeftInSourceSegment := BlockSize - addrSrc
		bytesLeftInTargetSegment := BlockSize - addrTgt

		if bytesToCopy < int(bytesLeftInSourceSegment) {
			bytesLeftInSourceSegment = uint16(bytesToCopy)
		}

		var bytesInThisStep uint16
		var i copyInstruction

		switch {
		case bytesLeftInSourceSegment == bytesLeftInTargetSegment:
			bytesInThisStep = bytesLeftInSourceSegment
			i = newInstruction(bytesInThisStep, addrSrc+uint16(SourceWindow), addrTgt+uint16(TargetWindow), mmuSrc, mmuTgt)
			mmuSrc++
			mmuTgt++
			addrSrc = 0
			addrTgt = 0
		case bytesLeftInSourceSegment < bytesLeftInTargetSegment:
			bytesInThisStep = bytesLeftInSourceSegment
			i = newInstruction(bytesInThisStep, addrSrc+uint16(SourceWindow), addrTgt+uint16(TargetWindow), mmuSrc, mmuTgt)
			mmuSrc++
			addrSrc = 0
			addrTgt += bytesInThisStep
		default:
			bytesInThisStep = bytesLeftInTargetSegment
			i = newInstruction(bytesInThisStep, addrSrc+uint16(SourceWindow), addrTgt+uint16(TargetWindow), mmuSrc, mmuTgt)
			mmuTgt++
			addrTgt = 0
			addrSrc += bytesInThisStep
		}

		bytesCopied += int(bytesInThisStep)

		numInstructions++
		instructions = append(instructions, i.toSlice()...)
		i.print()
		bytesToCopy -= int(bytesInThisStep)
	}

	if (bytesCopied != len(p.Segments[segPos].Data)) || (bytesToCopy != 0) {
		return nil, 0, fmt.Errorf("inconsistency when generating copy instructions. This should not happen")
	}

	return instructions, numInstructions, nil
}

func (p *PgzFile) CreateCopyInstructions(image []byte, index map[uint]uint, numBlocks int) error {
	image[NumBlocksAddress] = byte(numBlocks)
	instructions := []byte{}
	numInstructions := 0

	for i := range p.Segments {
		fmt.Printf("---------- Address: $%06x length: $%06X\n", p.Segments[i].Address, len(p.Segments[i].Data))
		newInst, numNewInst, err := p.InstructionsForOneSegment(i, index)
		if err != nil {
			return fmt.Errorf("unable to procss segment %d: %v", i, err)
		}

		numInstructions += numNewInst
		if numInstructions > MaxCopyInstructions-1 {
			return fmt.Errorf("too many copy instructions")
		}

		instructions = append(instructions, newInst...)

	}

	fmt.Println("---------- Stop instruction")
	stopInstruction := newInstruction(0, uint16(p.StartAddress), 0, 0, 0)
	stopInstruction.print()
	instructions = append(instructions, stopInstruction.toSlice()...)

	copy(image[CopyInstructions:], instructions)
	fmt.Printf("\nOverall %d of %d copy instructions were used\n", numInstructions, MaxCopyInstructions)

	return nil
}

func AddDocumentation(data []byte, name string, description string) error {
	newData := []byte{}
	newData = append(newData, []byte(name)...)
	newData = append(newData, 0x00)
	newData = append(newData, 0x00)
	newData = append(newData, []byte(description)...)
	newData = append(newData, 0x00)

	if len(newData) > MaxDocumentation {
		return fmt.Errorf("documentation too long")
	}

	copy(data[DescriptionAddress:], newData)

	return nil
}

func main() {
	runFlags := flag.NewFlagSet("pgz2flash", flag.ContinueOnError)
	pgzFileName := runFlags.String("pgz", "", "Path to pgz")
	progName := runFlags.String("name", "", "Name of program in flash and shown by lsf")
	description := runFlags.String("desc", "", "Description shown in lsf")
	outFile := runFlags.String("out", "", "Output file name")

	if err := runFlags.Parse(os.Args[1:]); err != nil {
		os.Exit(42)
	}

	if *pgzFileName == "" {
		fmt.Fprintln(os.Stderr, "No PGZ specified")
		os.Exit(42)
	}

	if *progName == "" {
		fmt.Fprintln(os.Stderr, "No progName specified")
		os.Exit(42)
	}

	if *description == "" {
		fmt.Fprintln(os.Stderr, "No description specified")
		os.Exit(42)
	}

	if *outFile == "" {
		fmt.Fprintln(os.Stderr, "No output file name given")
		os.Exit(42)
	}

	loaderBinary, err := getLoaderBinary()
	if err != nil {
		fmt.Fprintf(os.Stderr, "unable to get loader binary: %v\n", err)
		os.Exit(42)
	}

	pgz, err := NewPgzFromFile(*pgzFileName)
	if err != nil {
		fmt.Fprintf(os.Stderr, "unable to parse PGZ: %v\n", err)
		os.Exit(42)
	}

	pgz.PrintInfo()
	fmt.Println()

	if (pgz.StartAddress >= 0xA000) && (pgz.StartAddress < 0xC000) {
		fmt.Fprintf(os.Stderr, "this PGZ has a start address in RAM block 5 which is not supported: %06x\n", pgz.StartAddress)
		os.Exit(42)
	}

	image, ind, numBlocks := pgz.CatenateSegments(loaderBinary)

	err = AddDocumentation(image, *progName, *description)
	if err != nil {
		fmt.Fprintf(os.Stderr, "unable to add KUP documentation: %v\n", err)
		os.Exit(42)
	}

	fmt.Println("Generated copy instructions")
	fmt.Println("===========================")
	err = pgz.CreateCopyInstructions(image, ind, numBlocks)
	if err != nil {
		fmt.Fprintf(os.Stderr, "unable to add copy instructions: %v\n", err)
		os.Exit(42)
	}

	err = os.WriteFile(*outFile, image, 0660)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error writing output file: %v\n", err)
		os.Exit(42)
	}
}
