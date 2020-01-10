unexport GOBIN
export GO111MODULE=on
export GOPROXY=direct
export GOSUMDB=off

GO           ?= go
GOFMT        ?= $(GO)fmt
FIRST_GOPATH := $(firstword $(subst :, ,$(shell $(GO) env GOPATH)))
GOOPTS       ?=
GOHOSTOS     ?= $(shell $(GO) env GOHOSTOS)
GOHOSTARCH   ?= $(shell $(GO) env GOSHOSTARCH)

GO_VERSION        ?= $(shell $(GO) version)
GO_VERSION_NUMBER ?= $(word 3, $(GO_VERSION))

#VERSION := $(shell git describe --tags --addrev=0)
#REVISION := $(shell git rev-parse --short HEAD)

VERSION  := v0.0.1
REVISION := $(shell git rev-parse --short HEAD)

GOLANGCI_LINT :=
GOLANGCI_LINT_OPTS ?=
GOLANGCI_LINT_VERSION ?= v1.18.0

ifeq ($(GOHOSTOS),$(filter $(GOHOSTOS),linux darwin))
	ifeq ($(GOHOSTARCH),$(filter $(GOHOSTARCH),amd64 i386))
		GOLANGCI_LINT := $(FIRST_GOPATH)/bin/golangci-lint
	endif
endif

ifneq (,$(wildcard vendor))
	GOOPTS := $(GOOPTS) -mod=vendor
endif
pkgs := ./...

.PHONY: all
all: style lint unused build test

.PHONY: style
style:
	@echo ">> checking code style"
	@fmtRes=$$($(GOFMT) -d $$(find . -path ./vendor -prune -o -name '*.go' -print)); \
	if [ -n "$${fmtRes}" ]; then \
		echo "gofmt checking faild!"; echo "$${fmtRes};" echo; \
		echo "Plase ensure you are using $$($(GO) version) for formatting code."; \
		exit 1;\
	fi

.PHONY: deps
deps:
	@echo ">> getting dependencies"
	$(GO) mod download

.PHONY: test
test:
	@echo ">> running all tests"
	$(GO) test $(pkgs)

.PHONY: format
format:
	@echo ">> formatting code"
	$(GO) fmt $(pkgs)

.PHONY: vet
vet:
	@echo ">> vetting code"
	$(GO) vet $(GOOPTS) $(pkgs)

.PHONY: lint
lint: ${GOLANGCI_LINT}
ifdef GOLANGCI_LINT
	@echo ">> running golangci-lint"
	$(GO) list -e -compiled -test=true -export=false -deps=true -find=false -tags= -- ./... > /dev/null
	$(GOLANGCI_LINT) run $(GOLANGCI_LINT_OPTS) $(pkgs)
endif

.PHONY: unused
unused:
	@echo ">> running check for unused/missing packages in go.mod"
	$(GO) mod tidy
	ifeq (,$(wildcard vendor))
		@git diff --exit-code -- go.sum go.mod
	else
		@echo ">> running check for unused packages in vendor/"
		$(GO) mod vendor
		@git diff --exit-code -- go.sum go.mod vendor/
	endif

.PHONY: build
build:
	@echo ">> building binaries"
	GOOS=linux GOARCH=amd64 $(GO) build -o pixie_linux_amd64 main.go
	#$(GO) build -o $@ $(shell basename "$@")

.PHONY: run
run: $(MAIN)
	go run $<

.PHONY: help
help:
	@make2help ${MAKEFILE_LIST}

ifdef GOLANGCI_LINT
$(GOLANGCI_LINT):
	mkdir -p $(FIRST_GOPATH)/bin
	curl -sfL https://raw.githubusercontent.com/golangci/golangci-lint/$(GOLANGCI_LINT_VERSION)/install.sh \
		| sed -e '/install -d/d' \
		| sh -s -- -b $(FIRST_GOPATH)/bin $(GOLANGCI_LINT_VERSION)
endif
