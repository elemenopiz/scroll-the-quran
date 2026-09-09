# Shortcuts around Tools/. Everything here is runnable directly too — see `make help`.
SCHEME      := ScrollTheQuran
DESTINATION := platform=iOS Simulator,name=iPhone 17
DERIVED     := .build/DerivedData
SNAP        ?= tabbar-dark
ID          ?= tabbar-dark

.DEFAULT_GOAL := help
.PHONY: help gen build test verify ui snap diff capture tokens fmt clean

help: ## show this list
	@grep -hE '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/' | expand -t14

gen: ## regenerate ScrollTheQuran.xcodeproj from project.yml
	xcodegen generate

build: gen ## build the app for the iPhone 17 simulator
	xcodebuild build -scheme "$(SCHEME)" -destination "$(DESTINATION)" -derivedDataPath "$(DERIVED)" | xcbeautify

test: ## run the host unit tests (Swift Testing)
	cd Packages/ScrollKit && swift build && swift test

verify: ## the gate: xcodegen, content checks, host build + tests, simulator build
	Tools/verify.sh

ui: ## verify plus the XCUITest layout specs
	Tools/verify.sh --ui

snap: ## build, install, capture and compare a screen (make snap SNAP=reader-dark)
	Tools/verify.sh --snap $(SNAP)

capture: ## capture one screen from the booted simulator (make capture ID=home-dark)
	Tools/snapshot/capture.sh $(ID)

diff: ## compare an already-captured screen (make diff ID=tabbar-dark)
	Tools/snapshot/compare.sh $(ID)

tokens: ## reprint the measured colours behind DesignSystem/Tokens.swift
	Tools/snapshot/sample-colors.sh

fmt: ## swiftformat + swiftlint over the Swift sources
	swiftformat App Packages Widget UITests
	swiftlint lint --quiet

clean: ## remove build products and the generated project
	rm -rf .build ScrollTheQuran.xcodeproj Packages/ScrollKit/.build
