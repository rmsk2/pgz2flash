import sys

LINE_SIZE = 32

def gen_line(data):
    sys.stdout.write("    ")
    for i in data:
        sys.stdout.write(f"0x{i:02x}, ")
    sys.stdout.write("\n")

with open(sys.argv[1], "rb") as f:
    data = f.read()

print("package main\n\n")
print(f"var {sys.argv[2]} []byte = []byte {{")

while len(data) != 0:
    gen_line(data[:LINE_SIZE])
    data = data[LINE_SIZE:]

print("}")