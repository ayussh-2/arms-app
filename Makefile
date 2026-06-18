flags=--android-skip-build-dependency-validation

APP_DIR=arms

PAIR_IP=192.168.29.66:39149
CONNECT_IP=192.168.29.66:37321

dev:
	cd $(APP_DIR) && flutter run $(flags)

build:
	cd $(APP_DIR) && flutter build apk --release

install:
	adb install $(APP_DIR)/build/app/outputs/flutter-apk/app-release.apk

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