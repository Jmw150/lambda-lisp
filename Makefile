CSC=csc
CSI=csi
TARGET=chicken-lisp

.PHONY: all run test clean

all: $(TARGET)

$(TARGET): main.scm lib.scm
	$(CSC) main.scm -o $(TARGET)

run: $(TARGET)
	./$(TARGET)

test:
	$(CSI) -s tests.scm

clean:
	rm -f $(TARGET)
