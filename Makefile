# SSTP Shield (client) — dev/run helpers.
#
# On Linux the app creates an SSTP tunnel, which needs CAP_NET_ADMIN. That can't
# come from `flutter run`: the binary must be built, granted the capability, and
# launched through the generated `sstp-vpn` wrapper. This Makefile bundles that.
#
# Everyday use:
#   make run                  # build + grant privilege + launch (local variant)
#   make run VARIANT=foreign  # same, foreign variant
#   make dev                  # plain `flutter run` (fast; UI work, no tunnel)
#
# `make run` runs setup_privilege.sh, which calls sudo — so it will prompt for
# your password. Re-run it after every code change (a rebuild clears the
# capability).

# Which build to make: `local` (lib/main.dart) or `foreign` (lib/main_foreign.dart).
VARIANT ?= local
ifeq ($(VARIANT),foreign)
  TARGET := lib/main_foreign.dart
else ifeq ($(VARIANT),local)
  TARGET := lib/main.dart
else
  $(error VARIANT must be 'local' or 'foreign', got '$(VARIANT)')
endif

# Location of the sstp_vpn_plugin checkout that ships setup_privilege.sh.
# Override on the command line if yours lives elsewhere:  make run PLUGIN=/path
PLUGIN ?= ../Projects/sstp_vpn_plugin

PRIV_SCRIPT := $(PLUGIN)/tool/setup_privilege.sh
BUNDLE      := build/linux/x64/release/bundle
APP         := $(BUNDLE)/sstp_shield
WRAPPER     := $(BUNDLE)/sstp-vpn

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@echo "SSTP Shield (client) — make targets:"
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo "  (append VARIANT=foreign to build/run the foreign variant)"

.PHONY: run
run: build priv launch ## Full pipeline: build + grant privilege + launch

.PHONY: build
build: ## Build the release Linux bundle
	flutter build linux --release --target $(TARGET)

.PHONY: priv
priv: ## Grant CAP_NET_ADMIN to the built bundle (runs sudo; needs a prior build)
	@test -f "$(APP)" || { echo "error: $(APP) not found — run 'make build' first." >&2; exit 1; }
	@test -x "$(PRIV_SCRIPT)" || { echo "error: $(PRIV_SCRIPT) not found — set PLUGIN=/path/to/sstp_vpn_plugin." >&2; exit 1; }
	"$(PRIV_SCRIPT)" "$(APP)"

.PHONY: launch
launch: ## Launch the privileged wrapper (needs a prior 'make priv')
	@test -x "$(WRAPPER)" || { echo "error: $(WRAPPER) not found — run 'make priv' first." >&2; exit 1; }
	"$(WRAPPER)"

.PHONY: dev
dev: ## Plain `flutter run` on Linux (fast; no tunnel privilege, so connect won't work)
	flutter run -d linux --target $(TARGET)

.PHONY: analyze
analyze: ## Static analysis (matches CI)
	flutter analyze

.PHONY: clean
clean: ## Remove build artifacts
	flutter clean
