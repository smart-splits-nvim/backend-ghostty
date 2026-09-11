.PHONY: bridge

# Deprecated: the transport now runs through osascript, so nothing is built.
# The target stays so existing `make bridge` install hooks keep working.
bridge:
	@echo "backend-ghostty: 'make bridge' is deprecated and does nothing." >&2
	@echo "Remove it from your plugin manager's build step." >&2
