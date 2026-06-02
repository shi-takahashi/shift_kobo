#!/bin/sh
#
# Firebase の GoogleService-Info.plist を build configuration に応じて切り替える。
#   Release            -> config/prod  (本番 shift-kobo-online-prod)
#   それ以外(Debug等)  -> config/dev   (開発 shift-kobo-online)
#
# Android の src/release・src/debug の google-services.json source set に相当。
# Xcode の Runner ターゲットに「Run Script」Build Phase として登録して使う
# （Copy Bundle Resources より後ろに置くこと）。
#
set -e

if [ "${CONFIGURATION}" = "Release" ]; then
  ENV_DIR="prod"
else
  ENV_DIR="dev"
fi

SRC="${SRCROOT}/config/${ENV_DIR}/GoogleService-Info.plist"
DEST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"

if [ ! -f "${SRC}" ]; then
  echo "error: ${SRC} が見つかりません。ios/config/${ENV_DIR}/ に GoogleService-Info.plist を配置してください。" >&2
  exit 1
fi

cp "${SRC}" "${DEST}"
echo "GoogleService-Info.plist <- config/${ENV_DIR} (CONFIGURATION=${CONFIGURATION})"
