dev-backend:
	cd backend && bun dev

dev-app:
	clear && cd arms && flutter run --android-skip-build-dependency-validation -v
