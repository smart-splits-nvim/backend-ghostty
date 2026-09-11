.PHONY: bridge

bridge: bin/ghostty-smart-splits-bridge

bin/ghostty-smart-splits-bridge: bridge/main.swift Makefile
	@if [ "$$(uname -s)" != "Darwin" ]; then \
		echo "Skipping Ghostty bridge build: macOS is required"; \
	elif ! command -v swiftc >/dev/null 2>&1; then \
		echo "Skipping Ghostty bridge build: swiftc is unavailable"; \
	else \
		mkdir -p bin; \
		swiftc -O -framework Foundation -framework Carbon -framework OSAKit -o "$@" bridge/main.swift; \
	fi
