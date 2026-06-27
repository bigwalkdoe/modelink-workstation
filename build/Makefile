.PHONY: all core developer ai security enterprise clean validate docker-build help

EDITION ?= developer
OUTPUT_DIR ?= /tmp/modelink-iso
BUILD_SCRIPT := ./build/scripts/build/build-iso.sh

all: $(EDITION)

# ---- Build individual editions ----
core developer ai security enterprise:
	@echo "Building Modelink $(@) edition..."
	@sudo "$(BUILD_SCRIPT)" --edition "$@" --output "$(OUTPUT_DIR)"

# ---- Build in Docker ----
docker-build:
	@echo "Building Modelink $(EDITION) edition inside Docker..."
	docker build -t modelink-builder -f build/Dockerfile .
	mkdir -p "$(OUTPUT_DIR)"
	docker run --rm \
		--privileged \
		-v "$(OUTPUT_DIR):/output" \
		modelink-builder \
		--edition "$(EDITION)" --output /output

docker-build-all:
	@echo "Building all editions inside Docker (this will take a while)..."
	docker build -t modelink-builder -f build/Dockerfile .
	mkdir -p "$(OUTPUT_DIR)"
	for edition in core developer ai security enterprise; do \
		echo "=== Building $$edition ==="; \
		docker run --rm \
			--privileged \
			-v "$(OUTPUT_DIR):/output" \
			modelink-builder \
			--edition "$$edition" --output /output; \
	done

# ---- Build all editions (native) ----
build-all: core developer ai security enterprise
	@echo "All editions built in $(OUTPUT_DIR)"

# ---- Clean ----
clean:
	@echo "Cleaning build artifacts..."
	@sudo rm -rf "$(OUTPUT_DIR)"

# ---- Validate package lists ----
validate:
	@echo "Validating package lists..."
	@for f in build/packages/*.txt; do \
		ed=$$(basename "$$f" .txt); \
		count=$$(grep -v '^\s*#' "$$f" | grep -v '^\s*$$' | wc -l); \
		echo "  $$ed: $$count packages"; \
	done

# ---- Syntax check build scripts ----
check:
	@echo "Checking build scripts..."
	@bash -n build/scripts/build/build-iso.sh && echo "  build-iso.sh: OK"
	@bash -n build/scripts/chroot/01-system-config.sh && echo "  01-system-config.sh: OK"
	@bash -n build/scripts/chroot/02-kde-config.sh && echo "  02-kde-config.sh: OK"
	@bash -n build/scripts/post-install/first-boot.sh && echo "  first-boot.sh: OK"

# ---- Help ----
help:
	@echo "Modelink Workstation ISO Builder"
	@echo ""
	@echo "Usage:"
	@echo "  make <edition>      Build a specific edition"
	@echo "                      (core | developer | ai | security | enterprise)"
	@echo "  make docker-build   Build inside Docker container (recommended)"
	@echo "  make validate       Count packages per edition"
	@echo "  make check          Syntax-check all build scripts"
	@echo "  make clean          Remove all build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  EDITION=developer   Default edition to build"
	@echo "  OUTPUT_DIR=/tmp/modelink-iso"
	@echo ""
	@echo "Examples:"
	@echo "  make ai EDITION=ai"
	@echo "  make docker-build EDITION=enterprise OUTPUT_DIR=./isos"
