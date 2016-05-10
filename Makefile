PACKAGE = nettle
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=/usr --infodir=/tmp/trash
CONF_FLAGS = --disable-documentation
CFLAGS =

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/nettle_//;s/_.*//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

GMP_VERSION = 6.1.0-3
GMP_URL = https://github.com/amylum/gmp/releases/download/$(GMP_VERSION)/gmp.tar.gz
GMP_TAR = /tmp/gmp.tar.gz
GMP_DIR = /tmp/gmp
GMP_PATH = --with-lib-path=$(GMP_DIR)/usr/lib --with-include-path=$(GMP_DIR)/usr/include

.PHONY : default submodule deps manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(GMP_DIR) $(GMP_TAR)
	mkdir $(GMP_DIR)
	curl -sLo $(GMP_TAR) $(GMP_URL)
	tar -x -C $(GMP_DIR) -f $(GMP_TAR)

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && ./.bootstrap
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS)' ./configure $(PATH_FLAGS) $(CONF_FLAGS) $(GMP_PATH)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	rm -rf $(RELEASE_DIR)/tmp
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYINGv2 $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

