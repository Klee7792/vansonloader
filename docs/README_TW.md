# VansonLoader

**VansonLoader 是 VansonMod 的 dylib 版本，是從 VansonMod 執行階段派生出的注入環境浮窗工具。**

[English](../README.md) | [简体中文](./README_CN.md) | **繁體中文** | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## 簡介

**VansonMod** 是主要 TrollStore 應用，提供完整的獨立工作流：行程選擇、記憶體搜尋、進階指標工作流、RVA 補丁、腳本工具、歸檔管理和設定。

**VansonLoader** 是面向注入執行環境的派生成果，把 VM 的部分執行階段能力打包為 dylib，並在目標行程內提供浮窗面板。

## 與 VansonMod 的關係

- **VansonMod** 是主應用和主發布入口：[vaenshine/VansonMod](https://github.com/vaenshine/VansonMod)。
- **VansonLoader** 是同一專案方向下的 dylib 派生版本。
- VM 匯出的 mod 和腳本資料可在 Loader 支援的執行階段流程中使用。
- VansonMod 負責完整編輯能力，包括進階指標工作流、應用選擇、歸檔管理和全域設定。

## 目前範圍

- 注入行程內的浮窗面板和快速開啟按鈕。
- 記憶體搜尋面板、搜尋結果、記憶體瀏覽、值編輯、搜尋時間線恢復，以及上一次手動寫入撤回。
- 匯入和儲存 VM/VL `.vm` 與 `.vmsc` 資料。
- 已匯入 pointer 項目的數值顯示、寫入、鎖定式控制和結果 UI 模式。
- 已匯入 RVA 項目的執行階段 patch 與 restore。
- 已匯入 signature 項目的掃描、結果顯示和可選執行階段 patch。
- 帶 H5GG 風格輔助別名和 VM/VL 記憶體 API 的 JavaScript 腳本執行。
- 受執行環境支援時提供 watch 浮窗、指令 inspector 和 RVA 轉交路徑。

## 建置

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## 發布

VansonLoader 有獨立的發布腳本：

```sh
./scripts/release.sh
```

## 免責聲明

本專案用於安全研究、逆向工程學習及合規技術測試場景。

請在合法環境中使用，並尊重目標應用與系統的適用規則。使用產生的操作風險和法律責任由使用者自行承擔。

## 開源協議

GPL-3.0。詳見 [LICENSE](./LICENSE)。

## 分發與專案身分

VansonLoader 官方版本透過本儲存庫的 [Releases](https://github.com/vaenshine/vansonloader/releases) 頁面免費發布。

本專案倡導透過官方管道免費取得與免費分享。維護者對第三方付費轉售未修改的官方安裝包不予認可、背書或授權。GPL-3.0 授予的分發權利維持不變。

GPL-3.0 允許第三方收費分發原版或修改版。分發者須完整履行適用的 GPL-3.0 義務，包括保留必要聲明、隨附授權條款、提供完整對應原始碼，以及清楚標示修改版本。

VansonLoader 名稱、Logo、軟體套件標識及官方專案身分屬於受保護的專案標識。第三方分發者須清楚標示其獨立、非官方身分，並避免任何暗示 VansonLoader 專案或維護者授權、贊助、認可或關聯的展示方式。

詳細規則請參閱[商標與分發政策](../TRADEMARKS.md)。
