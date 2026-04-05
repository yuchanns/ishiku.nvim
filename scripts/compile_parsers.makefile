CFLAGS       ?= -Os -std=c99 -fPIC
CXX_STANDARD ?= c++14
CXXFLAGS     ?= -Os -std=$(CXX_STANDARD) -fPIC
LDFLAGS      ?=
SRC_DIR      ?= ./src
OUTPUT       ?= parser.so

ifeq ($(OS),Windows_NT)
   SHELL       := powershell.exe
   .SHELLFLAGS := -NoProfile -command
   TARGET      := parser.dll
   rmf         = Write-Output $(1) | foreach { if (Test-Path $$_) { Remove-Item -Force } }
else
   TARGET      := parser.so
   rmf         = rm -rf $(1)
endif

ifneq ($(wildcard $(SRC_DIR)/*.cc),)
   LDFLAGS += -lstdc++
endif

OBJECTS := parser.o

ifneq ($(wildcard $(SRC_DIR)/scanner.*),)
   OBJECTS += scanner.o
endif

all: $(OUTPUT)

$(OUTPUT): $(OBJECTS)
	$(CC) $(OBJECTS) -o $(OUTPUT) -shared $(LDFLAGS)

%.o: $(SRC_DIR)/%.c
	$(CC) -c $(CFLAGS) -I$(SRC_DIR) -o $@ $<

%.o: $(SRC_DIR)/%.cc
	$(CC) -c $(CXXFLAGS) -I$(SRC_DIR) -o $@ $<

clean:
	$(call rmf,$(TARGET) $(OUTPUT) $(OBJECTS))

.PHONY: clean
