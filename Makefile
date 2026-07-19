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

# The built SoftEther client binaries (vpnclient/vpncmd/hamcore.se2), bundled so
# the SoftEther protocol works. Build them once with the package's fetch script.
SOFTETHER_SRC ?= ../Projects/softether_client/softether

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@echo "SSTP Shield (client) — make targets:"
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo "  (append VARIANT=foreign to build/run the foreign variant)"

.PHONY: run
run: build stage-softether stage-tls-relay priv launch ## Full pipeline: build + bundle SoftEther + TLS relay + grant privilege + launch

# The Go/uTLS TLS relay, bundled beside the app so the SSTP protocol can get past
# networks that fingerprint-block Dart's TLS ClientHello. Auto-discovered by the
# app at <bundle>/tls-relay/sstp-tls-relay. Skipped (with a note) when Go is
# absent — SSTP then falls back to direct TLS.
.PHONY: stage-tls-relay
stage-tls-relay:
	@if command -v go >/dev/null 2>&1; then \
	  mkdir -p "$(BUNDLE)/tls-relay" && \
	  go build -C "$(PLUGIN)/go/tls_relay" -trimpath \
	    -o "$(abspath $(BUNDLE))/tls-relay/sstp-tls-relay" . && \
	  echo "==> TLS relay staged in $(BUNDLE)/tls-relay"; \
	else \
	  echo "==> go not found - SSTP will use direct TLS (no DPI evasion)."; \
	fi

# Staged for `run` too, so the SoftEther protocol works from a local build the
# same as from a release download. Skipped (with a note) rather than failing when
# the client hasn't been fetched — SSTP alone doesn't need it.
.PHONY: stage-softether
stage-softether:
	@if [ -f "$(SOFTETHER_SRC)/vpnclient" ]; then \
	  (cd "$(SOFTETHER_PKG)" && dart compile exe bin/softether_helper.dart \
	      -o softether/softether-helper >/dev/null) && \
	  mkdir -p "$(BUNDLE)/softether" && \
	  cp "$(SOFTETHER_SRC)/vpnclient" "$(SOFTETHER_SRC)/vpncmd" \
	     "$(SOFTETHER_SRC)/hamcore.se2" "$(SOFTETHER_SRC)/softether-helper" \
	     "$(BUNDLE)/softether/" && \
	  echo "==> SoftEther staged in $(BUNDLE)/softether"; \
	else \
	  echo "==> SoftEther client not built - SSTP only."; \
	  echo "    Run $(SOFTETHER_PKG)tool/fetch_softether.sh to enable it."; \
	fi

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

SOFTETHER_PKG := $(dir $(SOFTETHER_SRC))

.PHONY: softether
softether: build ## Build + bundle the SoftEther binaries and privileged helper (enables the SoftEther protocol)
	@test -f "$(SOFTETHER_SRC)/vpnclient" || { echo "error: $(SOFTETHER_SRC)/vpnclient not found — run $(SOFTETHER_PKG)tool/fetch_softether.sh first." >&2; exit 1; }
	@echo "==> compiling the privileged helper"
	cd "$(SOFTETHER_PKG)" && dart compile exe bin/softether_helper.dart -o softether/softether-helper
	mkdir -p "$(BUNDLE)/softether"
	cp "$(SOFTETHER_SRC)/vpnclient" "$(SOFTETHER_SRC)/vpncmd" \
	   "$(SOFTETHER_SRC)/hamcore.se2" "$(SOFTETHER_SRC)/softether-helper" "$(BUNDLE)/softether/"
	@echo "==> SoftEther staged in $(BUNDLE)/softether (binaries + helper)"
	@echo "    Run the app NORMALLY (unprivileged) — the helper elevates via pkexec:"
	@echo "        $(APP)"
	@echo "    Then Settings -> Protocol = SoftEther -> connect (polkit will prompt)."

.PHONY: analyze
analyze: ## Static analysis (matches CI)
	flutter analyze

# ---- Releasing --------------------------------------------------------------
# `make release VERSION=2.1.1` bumps the version, runs the CI-parity analyze,
# commits everything, tags vX.Y.Z, and pushes — which triggers the GitHub Actions
# release workflow that builds and publishes the APKs / Linux / Windows assets.
# The build number (the +N in pubspec) is auto-incremented.
.PHONY: release
release: ## Cut a release: make release VERSION=2.1.1 (bump, analyze, commit, tag, push)
	@test -n "$(VERSION)" || { echo "usage: make release VERSION=2.1.1" >&2; exit 1; }
	@echo "$(VERSION)" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$$' \
		|| { echo "error: VERSION must look like 2.1.1 (got '$(VERSION)')." >&2; exit 1; }
	@git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null \
		&& { echo "error: tag v$(VERSION) already exists." >&2; exit 1; } || true
	@build=$$(grep -E '^version:' pubspec.yaml | sed -E 's/.*\+//'); \
		next=$$((build + 1)); \
		sed -i -E "s/^version: .*/version: $(VERSION)+$$next/" pubspec.yaml; \
		echo "==> version bumped to $(VERSION)+$$next"
	flutter analyze
	git add -A
	git commit -m "Release v$(VERSION)"
	git tag "v$(VERSION)"
	git push origin HEAD
	git push origin "v$(VERSION)"
	@echo "==> pushed v$(VERSION). CI will build and publish the release:"
	@echo "    https://github.com/atasanbratan/sstp_shield/releases/tag/v$(VERSION)"
	@echo "    watch:  gh run watch \$$(gh run list --branch v$(VERSION) --limit 1 --json databaseId --jq '.[0].databaseId')"

.PHONY: clean
clean: ## Remove build artifacts
	flutter clean
