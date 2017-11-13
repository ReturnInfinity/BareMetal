TARGET_ARCHITECTURE ?= x86-64

.PHONY: all clean test install
all clean test install:
	$(MAKE) -C src/$(TARGET_ARCHITECTURE) $@

$(V).SILENT:
