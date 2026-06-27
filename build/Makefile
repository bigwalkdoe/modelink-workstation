.PHONY: all core developer ai security enterprise clean

EDITION ?= developer
OUTPUT_DIR ?= /tmp/modelink-iso

all: $(EDITION)

# Build a specific edition
core:
	@echo "Building Modelink Core edition..."
	@./build/scripts/build/build-iso.sh --edition core

developer:
	@echo "Building Modelink Developer edition..."
	@./build/scripts/build/build-iso.sh --edition developer

ai:
	@echo "Building Modelink AI edition..."
	@./build/scripts/build/build-iso.sh --edition ai

security:
	@echo "Building Modelink Security edition..."
	@./build/scripts/build/build-iso.sh --edition security

enterprise:
	@echo "Building Modelink Enterprise edition..."
	@./build/scripts/build/build-iso.sh --edition enterprise

# Build using Docker
docker-build:
	docker build -t modelink-builder -f build/Dockerfile .
	docker run --rm -v $(OUTPUT_DIR):/output \
		-v /var/run/docker.sock:/var/run/docker.sock \
		modelink-builder --edition $(EDITION)

# Set up edition-specific output directories
editions/%:
	@mkdir -p $(OUTPUT_DIR)/$*/

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(OUTPUT_DIR)

# Validate package lists
validate:
	@echo "Validating package lists..."
	@for f in build/packages/*.txt; do \
		echo "  Checking $$f..."; \
		while IFS= read -r pkg; do \
			[ -z "$$pkg" ] || [ "$${pkg:0:1}" = "#" ] && continue; \
			echo "    $$pkg"; \
		done < "$$f"; \
	done

# Build all editions
build-all: core developer ai security enterprise

help:
	@echo "Modelink Workstation ISO Builder"
	@echo ""
	@echo "Usage:"
	@echo "  make <edition>     Build a specific edition (core|developer|ai|security|enterprise)"
	@echo "  make EDITION=ai    Build with default edition set to AI"
	@echo "  make docker-build  Build inside Docker container"
	@echo "  make clean         Remove build artifacts"
	@echo "  make build-all     Build all editions"
	@echo "  make validate      Validate package lists"
	@echo ""
	@echo "Editions:"
	@echo "  core       - Lightweight engineering base"
	@echo "  developer  - Full-stack development environment"
	@echo "  ai         - Optimized for local LLM and AI agents"
	@echo "  security   - Focused on defensive security"
	@echo "  enterprise - Organizational deployment readiness"
