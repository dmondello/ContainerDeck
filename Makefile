APP_NAME = ContainerDeck
BUILD_DIR = .build/release
DIST_DIR = dist
APP_BUNDLE = $(DIST_DIR)/$(APP_NAME).app

# Identità di firma: ad-hoc ("-") di default, sovrascrivibile con
#   make app SIGN_IDENTITY="Developer ID Application: Nome (TEAMID)"
SIGN_IDENTITY ?= -

VERSION := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
DMG = $(DIST_DIR)/$(APP_NAME)-$(VERSION).dmg
DMG_STAGING = $(DIST_DIR)/dmg-staging

# Profilo credenziali notarytool, creato una tantum con:
#   xcrun notarytool store-credentials containerdeck-notary \
#     --apple-id <email> --team-id <TEAMID> --password <app-specific-password>
NOTARY_PROFILE ?= containerdeck-notary

.PHONY: build run test app dmg notarize clean

build:
	swift build -c release --arch arm64

run:
	swift run

# Suite di test autonoma (nessun Xcode richiesto): l'eseguibile gira le
# asserzioni con --run-tests e ritorna un exit code non-zero se fallisce.
test:
	swift run ContainerDeck --run-tests

app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/
	codesign --force --sign "$(SIGN_IDENTITY)" --options runtime $(APP_BUNDLE) || \
		codesign --force --sign "$(SIGN_IDENTITY)" $(APP_BUNDLE)
	@echo "✅ Bundle creato: $(APP_BUNDLE)"
	@echo "   Installa con: cp -r $(APP_BUNDLE) /Applications/"

# Immagine disco per la distribuzione: app + link ad Applicazioni per il
# drag-and-drop, con icona personalizzata anche sul volume montato
# (richiede il passaggio UDRW → SetFile → UDZO).
dmg: app
	rm -rf $(DMG_STAGING) $(DMG) $(DIST_DIR)/tmp.dmg
	mkdir -p $(DMG_STAGING)
	cp -R $(APP_BUNDLE) $(DMG_STAGING)/
	ln -s /Applications $(DMG_STAGING)/Applications
	cp Resources/AppIcon.icns $(DMG_STAGING)/.VolumeIcon.icns
	hdiutil create -volname "$(APP_NAME)" -srcfolder $(DMG_STAGING) -ov -format UDRW -quiet $(DIST_DIR)/tmp.dmg
	hdiutil attach $(DIST_DIR)/tmp.dmg -mountpoint /tmp/$(APP_NAME)-dmg -quiet
	-SetFile -a C /tmp/$(APP_NAME)-dmg
	hdiutil detach /tmp/$(APP_NAME)-dmg -quiet
	hdiutil convert $(DIST_DIR)/tmp.dmg -format UDZO -o $(DMG) -quiet
	rm -f $(DIST_DIR)/tmp.dmg
	rm -rf $(DMG_STAGING)
	@echo "✅ DMG creato: $(DMG)"

# Notarizzazione Apple: richiede SIGN_IDENTITY="Developer ID Application: …"
# e il profilo credenziali NOTARY_PROFILE già salvato nel keychain.
#   make notarize SIGN_IDENTITY="Developer ID Application: Nome (TEAMID)"
notarize: dmg
	xcrun notarytool submit $(DMG) --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(DMG)
	@echo "✅ DMG notarizzato e pronto per la distribuzione: $(DMG)"

clean:
	rm -rf .build $(DIST_DIR)
