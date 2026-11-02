#!/usr/bin/env bash
# ساخت/استفاده از keystore امضای release.
# رمز از GitHub Secret به نام KEYSTORE_PASSWORD می‌آید. فایل keystore (که با همین رمز
# رمزگذاری شده) در مخزن نگه داشته می‌شود تا نسخه‌های بعدی با همان امضا ساخته شوند.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KS_DIR="$ROOT/keystore"
KS="$KS_DIR/taraz.jks"
ALIAS="taraz"

if [ -z "${KEYSTORE_PASSWORD:-}" ]; then
  echo "::error title=KEYSTORE_PASSWORD missing::Secret «KEYSTORE_PASSWORD» تعریف نشده است. در گیت‌هاب: Settings → Secrets and variables → Actions → New repository secret"
  echo "KEYSTORE_PASSWORD secret is missing" > "$ROOT/ci/build.log"
  exit 1
fi

mkdir -p "$KS_DIR"
if [ ! -f "$KS" ]; then
  echo "Generating new release keystore…"
  keytool -genkeypair -v \
    -keystore "$KS" -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10950 \
    -storepass "$KEYSTORE_PASSWORD" -keypass "$KEYSTORE_PASSWORD" \
    -dname "CN=Taraz, OU=Taraz, O=Sivan, L=Sanandaj, C=IR"
  echo "NEW_KEYSTORE=1" >> "${GITHUB_ENV:-/dev/null}"
else
  # بررسی این‌که رمز با keystore موجود می‌خواند
  if ! keytool -list -keystore "$KS" -storepass "$KEYSTORE_PASSWORD" -alias "$ALIAS" >/dev/null 2>&1; then
    echo "::error title=Keystore password mismatch::رمز KEYSTORE_PASSWORD با فایل keystore/taraz.jks موجود نمی‌خواند. یا رمز قبلی را برگردانید یا فایل keystore را حذف کنید (در این صورت امضای اپ عوض می‌شود و نسخهٔ قبلی باید حذف و دوباره نصب شود)."
    exit 1
  fi
fi

cat > "$ROOT/android/key.properties" <<EOF
storePassword=$KEYSTORE_PASSWORD
keyPassword=$KEYSTORE_PASSWORD
keyAlias=$ALIAS
storeFile=$KS
EOF
echo "key.properties written (storeFile=$KS)"
