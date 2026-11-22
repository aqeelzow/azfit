# AZfit developer commands. Run `make help`.
.DEFAULT_GOAL := help
SHELL := /bin/bash

PACKAGES := AZKit Bridge
SWIFT_DIRS := App/Sources App/Tests Bridge/App $(foreach p,$(PACKAGES),$(p)/Sources $(p)/Tests $(p)/Package.swift)

# With only the Command Line Tools (no Xcode), Swift Testing needs its framework paths spelled out.
# With Xcode selected this is empty. See docs/decisions.md D-014.
CLT := /Library/Developer/CommandLineTools/Library/Developer
ifeq ($(shell xcode-select -p 2>/dev/null),/Library/Developer/CommandLineTools)
TEST_FLAGS := -Xswiftc -F$(CLT)/Frameworks -Xlinker -F$(CLT)/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Frameworks -Xlinker -rpath -Xlinker $(CLT)/usr/lib
endif

.PHONY: help bootstrap gen open test test-% lint format design check clean

help: ## Show this help
	@grep -E '^[a-zA-Z%_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[1m%-12s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Install tools (XcodeGen) and resolve packages
	@command -v xcodegen >/dev/null || brew install xcodegen
	@for p in $(PACKAGES); do (cd $$p && swift package resolve) || exit 1; done

gen: ## Generate AZfit.xcodeproj from project.yml
	xcodegen generate

open: gen ## Generate and open in Xcode
	open AZfit.xcodeproj

test: $(addprefix test-,$(PACKAGES)) ## Run every package's tests

test-%: ## Run one package's tests, e.g. make test-AZKit
	cd $* && swift test $(TEST_FLAGS)

lint: ## Check formatting and lint rules (fails on any warning)
	swift format lint --strict -r $(SWIFT_DIRS)
	@! grep -rn --exclude-dir=.build --include='*.swift' --include='*.md' --include='*.json' $$'\xe2\x80\x94' App AZKit Div Bridge docs/*.md CLAUDE.md README.md \
		|| (echo "em dash found: use '-'" && false)

format: ## Format all Swift code in place
	swift format format -i -r $(SWIFT_DIRS)

design: ## Rebuild design/screens and design/index.html from design/source
	python3 design/source/build.py

check: lint test ## What CI runs

clean: ## Remove build output and the generated project
	rm -rf AZfit.xcodeproj $(foreach p,$(PACKAGES),$(p)/.build) design/.publish
