flags=--android-skip-build-dependency-validation

APP_DIR=arms
KEY_TOOL_DIR=D:/Softwares/Android/jbr/bin/keytool.exe
KEYSTORE_NAME=keys/arms-release.jks
KEY_ALIAS=arms-key
BACKEND_DIR=D:/Projects/Personal/ARMS

PAIR_IP=192.168.29.66:39149
CONNECT_IP=192.168.29.66:34005

DEV_URL=http://192.168.29.188:6582/api/graphql
PROD_URL=https://arms.pariksit.com/api/graphql


dev:
	cd $(APP_DIR) && flutter run --dart-define=BASE_API_URL=$(DEV_URL) $(flags)

dev-prod:
	cd $(APP_DIR) && flutter run --dart-define=BASE_API_URL=$(PROD_URL) $(flags)


dev-server:
	cd ${BACKEND_DIR} && bun dev

build:
	cd $(APP_DIR) && flutter build apk --release --split-per-abi --dart-define=BASE_API_URL=$(API_URL)

install:
	adb install $(APP_DIR)/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
clean:
	cd $(APP_DIR) && flutter clean

update:
	cd $(APP_DIR) && flutter pub get

pair:
	adb pair $(PAIR_IP)

connect:
	adb connect $(CONNECT_IP)

devices:
	adb devices
	flutter devices

wireless: connect devices

disconnect:
	adb disconnect

logs:
	adb logcat

restart-adb:
	adb kill-server
	adb start-server

gen-key:
	mkdir -p keys
	"$(KEY_TOOL_DIR)" -genkey -v -keystore $(KEYSTORE_NAME) -keyalg RSA -keysize 2048 -validity 10000 -alias $(KEY_ALIAS)

encode-key:
	powershell -Command "[Convert]::ToBase64String([IO.File]::ReadAllBytes('$(KEYSTORE_NAME)')) | Out-File -NoNewline keys/keystore_b64.txt"
	@echo Done! Open keys/keystore_b64.txt and copy contents to GitHub secret KEYSTORE_BASE64