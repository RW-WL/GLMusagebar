.PHONY: build run clean install

build:
	bash build.sh

run: build
	open build/GLMUsageBar.app

clean:
	rm -rf build

install: build
	cp -R build/GLMUsageBar.app /Applications/