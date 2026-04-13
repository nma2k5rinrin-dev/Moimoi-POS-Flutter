#!/usr/bin/env bash

echo "======================================================="
echo "    MOIMOI POS - SEMANTIC VERSIONING KICKSTARTER"
echo "======================================================="
echo ""

if [ -z "$1" ]; then
    echo "[LOI] Trang thai phien ban hien tai la:"
    dart run cider version
    echo ""
    echo "Vui long truyen vao loai cap nhat ban muon thuc hien:"
    echo "Cu phap: ./bump.sh [build|patch|minor|major]"
    echo ""
    echo "  build : Tang so ban dung    - De test APK"
    echo "  patch : Sua loi nho ngam    - Cap nhat ngam"
    echo "  minor : Them Tinh Nang Moi  - Tinh nang to / Giao dien"
    echo "  major : Dai tu ung dung     - Dap di xay lai"
    exit 1
fi

echo "[1/3] Dang nang cap phien ban theo loai: $1 ..."
dart run cider bump $1

echo ""
echo "[2/3] Dang ghi log vao CHANGELOG.md ..."
dart run cider release

echo ""
echo "[3/3] Hoan tat! Phien ban hien tai cua ung dung (pubspec.yaml):"
dart run cider version
echo ""
echo "Luu y: Ban nen chay 'git add pubspec.yaml CHANGELOG.md'"
echo "sau do Commit voi loi nhan: 'chore: bump version'"
