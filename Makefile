APP = build/WindowCarousel.app

.PHONY: app run

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/WindowCarousel $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	codesign --force --sign "Apple Development" $(APP)

run: app
	pkill -x WindowCarousel || true
	open $(APP)
