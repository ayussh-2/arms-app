flags=--android-skip-build-dependency-validation
dev:
	cd arms && flutter run ${flags}
build:
	cd arms && flutter build apk --release -v

install:
	cd arms/build/app/outputs/flutter-apk && adb install app-release.apk

clean:
	cd arms && flutter clean

update:
	cd arms && flutter pub get