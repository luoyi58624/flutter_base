flutter --version
flutter pub get

# shellcheck disable=SC2164
cd ./examples/android_app
flutter build web --web-renderer=html --pwa-strategy none --base-href /flutter_base/
