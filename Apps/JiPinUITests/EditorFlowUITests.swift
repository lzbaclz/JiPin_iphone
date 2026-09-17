import XCTest

final class EditorFlowUITests: XCTestCase {
    func testV3HomeOpensDecoratedSample() {
        let app = XCUIApplication()
        app.launch()
        let start = app.buttons["home-try-stickers"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        for _ in 0..<4 where !start.isHittable { app.swipeUp() }
        start.tap()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["sticker-library-open"].exists)
        keepVersionScreenshot(app, name: "v3-sticker-diary")
    }

    func testV3StickerLibrarySearchFavoriteAndExport() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "freeform"]
        app.launch()
        tapTool(app, id: "tool-sticker", label: "贴纸")
        app.buttons["sticker-library-open"].tap()
        XCTAssertTrue(app.navigationBars["贴纸册"].waitForExistence(timeout: 5))
        keepVersionScreenshot(app, name: "v3-cute-stickers")
        let favorite = app.buttons["收藏软软兔"]
        if favorite.value as? String != "已收藏" { favorite.tap() }
        app.switches["sticker-favorites-only"].tap()
        XCTAssertTrue(app.buttons["sticker-add-cute-bunny"].exists)
        app.switches["sticker-favorites-only"].tap()
        let search = app.textFields["sticker-library-search"]
        search.tap(); search.typeText("bunny\n")
        XCTAssertTrue(app.buttons["sticker-add-cute-bunny"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sticker-add-cute-bear"].exists)
        app.buttons["sticker-add-cute-bunny"].tap()
        let canvas = app.descendants(matching: .any)["editor-canvas"]
        XCTAssertTrue((canvas.value as? String ?? "").contains("软软兔"))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5)).press(forDuration: 0.15,
            thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7,dy: 0.3)))
        keepVersionScreenshot(app, name: "v3-sticker-on-canvas")
        app.buttons["editor-export"].tap()
        let generate = app.buttons["export-generate"]
        for _ in 0..<4 where !generate.isHittable { app.swipeUp() }
        XCTAssertTrue(generate.isHittable)
        generate.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '已生成'")).firstMatch.waitForExistence(timeout: 25))
    }

    func testV3CoolStickersAndDecorativeFrameCanBeAppliedAndRemoved() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "template"]
        app.launch()
        tapTool(app, id: "tool-sticker", label: "贴纸")
        app.buttons["sticker-library-open"].tap()
        app.buttons["sticker-category-cool"].tap()
        XCTAssertTrue(app.buttons["sticker-add-cool-bolt"].exists)
        XCTAssertTrue(app.buttons["sticker-add-cool-orbit"].exists)
        keepVersionScreenshot(app, name: "v3-cool-stickers")
        app.buttons["sticker-add-cool-bolt"].tap()
        tapTool(app, id: "tool-border", label: "边框")
        app.buttons["frame-gallery-open"].tap()
        XCTAssertTrue(app.navigationBars["可爱边框"].waitForExistence(timeout: 5))
        keepVersionScreenshot(app, name: "v3-frame-gallery")
        app.buttons["frame-apply-cream-lace"].tap()
        XCTAssertTrue(app.buttons["frame-remove-inline"].waitForExistence(timeout: 5))
        app.buttons["frame-remove-inline"].tap()
        XCTAssertFalse(app.buttons["frame-remove-inline"].exists)
        app.buttons["撤销"].tap()
        XCTAssertTrue(app.buttons["frame-remove-inline"].exists)
    }

    func testV2StyleApplySaveAndReload() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "template"]
        app.launch()
        XCTAssertTrue(app.buttons["tool-style"].waitForExistence(timeout: 10))
        app.buttons["tool-style"].tap()
        app.buttons["style-gallery-open"].tap()
        XCTAssertTrue(app.navigationBars["风格工作室"].waitForExistence(timeout: 5))
        keepVersionScreenshot(app, name: "v2-style-studio")
        app.buttons["style-apply-cream"].tap()
        XCTAssertTrue(app.buttons["撤销"].isEnabled)
        app.buttons["style-gallery-open"].tap()
        let save = app.buttons["style-save-current"]
        for _ in 0..<5 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.alerts["保存风格"].waitForExistence(timeout: 4))
        app.alerts["保存风格"].buttons["保存"].tap()
        XCTAssertTrue(app.buttons["套用我的日常风格"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["套用我的日常风格"].firstMatch.isHittable)
        XCTAssertTrue(app.staticTexts["style-saved-notice"].exists)
        keepVersionScreenshot(app, name: "402-saved-personal-style")
        app.navigationBars["风格工作室"].buttons["完成"].tap()
        app.buttons["style-gallery-open"].tap()
        let saved = app.buttons["套用我的日常风格"].firstMatch
        for _ in 0..<5 where !saved.isHittable { app.swipeUp() }
        XCTAssertTrue(saved.isHittable)
    }

    func testV2DividerCanResizeAndReset() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "template"]
        app.launch()
        let open = app.buttons["layout-dividers-open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        if !open.isHittable { app.scrollViews["editor-tool-panel"].swipeUp() }
        open.tap()
        XCTAssertTrue(app.navigationBars["分隔线"].waitForExistence(timeout: 5))
        let slider = app.sliders.matching(NSPredicate(format: "identifier BEGINSWITH 'divider-'")).firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 4))
        slider.adjust(toNormalizedSliderPosition: 0.72)
        keepVersionScreenshot(app, name: "v2-divider-editor")
        let reset = app.buttons["layout-dividers-reset"]
        for _ in 0..<3 where !reset.isHittable { app.swipeUp() }
        XCTAssertTrue(reset.isEnabled)
        reset.tap()
        XCTAssertFalse(reset.isEnabled)
    }

    func testV2LongStripPagesGenerateAndShare() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "longStrip"]
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 10))
        app.buttons["editor-export"].tap()
        let pages = app.buttons["export-pages"]
        for _ in 0..<4 where !pages.isHittable { app.swipeUp() }
        XCTAssertTrue(pages.isHittable)
        pages.tap()
        XCTAssertTrue(app.staticTexts["pages-plan"].waitForExistence(timeout: 5))
        keepVersionScreenshot(app, name: "v2-paged-export")
        let generate = app.buttons["pages-generate"]
        for _ in 0..<3 where !generate.isHittable { app.swipeUp() }
        generate.tap()
        XCTAssertTrue(app.staticTexts["pages-result"].waitForExistence(timeout: 30))
        let share = app.buttons["pages-share"]
        for _ in 0..<3 where !share.isHittable { app.swipeUp() }
        share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10)
                      || app.collectionViews["ActivityListView"].waitForExistence(timeout: 2)
                      || app.sheets.firstMatch.waitForExistence(timeout: 2))
    }

    private func keepVersionScreenshot(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testFourModesOpenEditorChrome() {
        for mode in ["template", "freeform", "poster", "longStrip"] {
            let app = XCUIApplication()
            app.launchArguments = ["-sampleEditor", "-sampleMode", mode]
            app.launch()
            XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 10), "missing export in \(mode)")
            XCTAssertTrue(app.buttons["完成"].exists)
            if mode == "template" {
                XCTAssertTrue(app.buttons["template-seamless"].exists || app.buttons["无缝"].exists)
            }
            tapToolbarItem(app, id: "editor-rename")
            XCTAssertTrue(app.alerts["重命名草稿"].waitForExistence(timeout: 4), "missing rename alert in \(mode)")
            app.alerts["重命名草稿"].buttons["取消"].tap()
            app.terminate()
        }
    }

    func testTemplateExportGeneratesFile() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "template"]
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 10))
        app.buttons["editor-export"].tap()
        let generate = app.buttons["export-generate"]
        XCTAssertTrue(generate.waitForExistence(timeout: 8))
        generate.tap()
        let generated = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '已生成'")
        ).firstMatch
        let actualSize = app.staticTexts.matching(
            NSPredicate(format: "(label CONTAINS 'KB' OR label CONTAINS 'MB') AND NOT label CONTAINS '预估'")
        ).firstMatch
        XCTAssertTrue(
            generated.waitForExistence(timeout: 25) || actualSize.waitForExistence(timeout: 2),
            "export did not produce an encoded file"
        )
    }

    func testStoreScreenshotAttachments() {
        func keep(_ app: XCUIApplication, name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
        }

        let home = XCUIApplication()
        home.launch()
        XCTAssertTrue(home.navigationBars["极拼"].waitForExistence(timeout: 8) || home.staticTexts["极拼"].waitForExistence(timeout: 2))
        keep(home, name: "01-create-home")
        home.buttons["设置"].tap()
        XCTAssertTrue(home.navigationBars["设置"].waitForExistence(timeout: 6))
        keep(home, name: "05-settings")
        home.terminate()

        for (mode, name) in [("template", "02-editor-template"), ("freeform", "03-editor-freeform")] {
            let app = XCUIApplication()
            app.launchArguments = ["-sampleEditor", "-sampleMode", mode]
            app.launch()
            XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 12))
            keep(app, name: name)
            app.terminate()
        }

        let quick = XCUIApplication()
        quick.launchArguments = ["-quickCollage"]
        quick.launch()
        XCTAssertTrue(quick.buttons["quick-cancel"].waitForExistence(timeout: 10))
        keep(quick, name: "04-quick-collage")
    }

    func testHomeShowsFourModes() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["极拼"].waitForExistence(timeout: 8) || app.staticTexts["极拼"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["选择照片"].waitForExistence(timeout: 4) || app.otherElements["home-pick-photos"].exists)
        for id in ["mode-template", "mode-freeform", "mode-poster", "mode-longStrip"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 4) || app.otherElements[id].exists, "missing \(id)")
        }
    }

    func testQuickCollageCancelAndOverflow() {
        let app = XCUIApplication()
        app.launchArguments = ["-quickCollage", "-quickCollageOverflow", "-quickCollageFailed"]
        app.launch()
        let consent = app.alerts["确认导入的照片"]
        XCTAssertTrue(consent.waitForExistence(timeout: 10))
        consent.buttons.matching(NSPredicate(format: "label CONTAINS '继续使用'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["quick-cancel"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["quick-overflow"].waitForExistence(timeout: 4) || app.staticTexts["quick-overflow"].exists)
        XCTAssertTrue(app.otherElements["quick-failed"].exists || app.staticTexts["quick-failed"].exists)
        XCTAssertTrue(app.buttons["quick-more"].exists)
        XCTAssertTrue(app.buttons["quick-save-album"].exists)
        XCTAssertTrue(app.buttons["quick-share"].isEnabled)
        XCTAssertTrue(app.segmentedControls["quick-content-mode"].exists || app.buttons["铺满裁切"].exists)
        XCTAssertTrue(app.buttons["quick-bg-photo"].exists || app.buttons["选图作背景"].exists)
        XCTAssertTrue(app.buttons["quick-seamless"].exists || app.buttons["无缝拼接"].exists)
        app.buttons["quick-cancel"].tap()
        XCTAssertTrue(app.navigationBars["极拼"].waitForExistence(timeout: 8) || app.staticTexts["极拼"].waitForExistence(timeout: 4))
    }

    func testQuickCollageTooFewBlocksSave() {
        let app = XCUIApplication()
        app.launchArguments = ["-quickCollage", "-quickCollageTooFew"]
        app.launch()
        XCTAssertTrue(app.staticTexts["扩展支持 1–9 张照片"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["quick-more"].isEnabled)
        XCTAssertFalse(app.buttons["quick-save-album"].isEnabled)
        XCTAssertFalse(app.buttons["quick-share"].isEnabled)
    }

    func testQuickSinglePhotoStartsInLongStripAndCanShare() {
        let app = XCUIApplication()
        app.launchArguments = ["-quickCollage", "-quickCollageSingle"]
        app.launch()
        XCTAssertTrue(app.buttons["quick-share"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["quick-save-album"].isEnabled)
        XCTAssertTrue(app.buttons["横向"].exists)
        XCTAssertFalse(app.segmentedControls.buttons["模板"].exists)
        app.buttons["横向"].tap()
        app.buttons["quick-share"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 25)
            || app.collectionViews["ActivityListView"].waitForExistence(timeout: 2)
            || app.sheets.firstMatch.waitForExistence(timeout: 2), app.debugDescription)
    }

    func testQuickSinglePhotoImportFailureRequiresConfirmation() {
        let app = XCUIApplication()
        app.launchArguments = ["-quickCollage", "-quickCollageSingle", "-quickCollageFailed"]
        app.launch()
        let alert = app.alerts["确认导入的照片"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.buttons["继续使用这 1 张"].exists)
        alert.buttons["继续使用这 1 张"].tap()
        XCTAssertTrue(app.buttons["quick-share"].isEnabled)
        XCTAssertTrue(app.buttons["横向"].exists)
    }

    func testQuickCollageSaveDraftAppearsInDrafts() {
        let app = XCUIApplication()
        app.launchArguments = ["-quickCollage"]
        app.launch()
        tapQuickDraft(app)
        let saved = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '草稿已保存'")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 12))
        app.buttons["quick-cancel"].tap()
        XCTAssertTrue(app.tabBars.buttons["草稿"].waitForExistence(timeout: 8))
        app.tabBars.buttons["草稿"].tap()
        let fromAlbum = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS '来自相册' OR label CONTAINS '相册快拼'")
        ).firstMatch
        XCTAssertTrue(fromAlbum.waitForExistence(timeout: 8))
    }

    func testQuickCollageShareDoesNotRequireAlbumSave() {
        let app = XCUIApplication()
        app.launchArguments = ["-quickCollage"]
        app.launch()
        let share = app.buttons["quick-share"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        XCTAssertTrue(share.isEnabled)
        share.tap()
        XCTAssertTrue(
            app.otherElements["ActivityListView"].waitForExistence(timeout: 25)
                || app.collectionViews["ActivityListView"].waitForExistence(timeout: 2)
                || app.navigationBars["分享"].waitForExistence(timeout: 2)
                || app.sheets.firstMatch.waitForExistence(timeout: 2),
            "share should generate JPEG without first saving to the album"
        )
    }

    func testModePickerExplainsSingleAndSeventeenPhotos() {
        let single = XCUIApplication()
        single.launchArguments = ["-sampleModePicker", "-samplePhotoCount", "1"]
        single.launch()
        XCTAssertTrue(single.navigationBars["选择模式"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            single.descendants(matching: .any)["mode-hint-single"].waitForExistence(timeout: 4)
                || single.staticTexts.matching(NSPredicate(format: "label CONTAINS '自由拼图、海报拼图或长图'")).firstMatch.waitForExistence(timeout: 2)
        )
        XCTAssertTrue(single.buttons["开始"].waitForExistence(timeout: 4))
        single.terminate()

        let many = XCUIApplication()
        many.launchArguments = ["-sampleModePicker", "-samplePhotoCount", "17"]
        many.launch()
        XCTAssertTrue(many.navigationBars["选择模式"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            many.descendants(matching: .any)["mode-hint-longstrip-only"].waitForExistence(timeout: 4)
                || many.staticTexts.matching(NSPredicate(format: "label CONTAINS '只能使用长图'")).firstMatch.waitForExistence(timeout: 2)
        )
        XCTAssertTrue(many.buttons["开始"].exists)
    }

    func testTemplateLayerPanelHasReorderButtons() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "template"]
        app.launch()
        tapToolbarItem(app, id: "editor-layers")
        XCTAssertTrue(app.navigationBars["图层"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["置顶"].exists)
        XCTAssertTrue(app.buttons["置底"].exists)
        XCTAssertTrue(app.buttons["上移一层"].exists)
    }

    func testEditorCanvasZoomButtonsExist() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "longStrip"]
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["canvas-zoom-in"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["longstrip-seamless"].exists || app.buttons["无缝拼接"].exists)
        app.buttons["canvas-zoom-in"].tap()
        XCTAssertTrue(app.buttons["canvas-zoom-reset"].exists)
        app.buttons["canvas-zoom-reset"].tap()
        XCTAssertTrue(app.buttons["canvas-zoom-out"].exists)
    }

    func testSettingsExplainsAlbumEntry() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["设置"].waitForExistence(timeout: 8))
        app.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 6))
        let help = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '操作区选择'")).firstMatch
        if !help.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(help.waitForExistence(timeout: 6))
        let privacy = app.buttons["隐私政策"]
        if !privacy.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(privacy.waitForExistence(timeout: 6))
        privacy.tap()
        XCTAssertTrue(app.navigationBars["隐私政策"].waitForExistence(timeout: 6))
        app.navigationBars["隐私政策"].buttons.firstMatch.tap()
        let support = app.buttons["支持与帮助"]
        if !support.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(support.waitForExistence(timeout: 6))
        support.tap()
        XCTAssertTrue(app.navigationBars["支持与帮助"].waitForExistence(timeout: 6))
    }

    func testFreeformLayoutExposesCanvasRatioAndSnap() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "freeform"]
        app.launch()
        tapTool(app, id: "tool-layout", label: "布局")
        XCTAssertTrue(
            app.switches["canvas-snap-toggle"].waitForExistence(timeout: 6)
                || app.switches["对齐吸附"].waitForExistence(timeout: 2),
            "freeform layout tool should expose the snap toggle"
        )
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '自定义宽'")).firstMatch.waitForExistence(timeout: 4)
                || app.buttons["自定义"].waitForExistence(timeout: 2)
        )
    }

    func testCopyModeAndSharedToolsAreReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "freeform"]
        app.launch()
        tapToolbarItem(app, id: "editor-copy-mode")
        XCTAssertTrue(app.navigationBars["复制到其他模式"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["创建副本"].exists)
        app.buttons["取消"].tap()

        tapTool(app, id: "tool-text", label: "文字")
        XCTAssertTrue(app.buttons["添加文字"].waitForExistence(timeout: 4))

        tapTool(app, id: "tool-doodle", label: "涂鸦")
        XCTAssertTrue(app.buttons["清除涂鸦"].waitForExistence(timeout: 4) || app.segmentedControls["doodle-brush-mode"].waitForExistence(timeout: 4))

        tapTool(app, id: "tool-sticker", label: "贴纸")
        XCTAssertTrue(app.buttons["shape-arrow"].waitForExistence(timeout: 6), "geometry shapes should be reachable")
        app.buttons["shape-arrow"].tap()
        XCTAssertTrue(app.buttons["填充"].waitForExistence(timeout: 4) || app.colorWells.firstMatch.waitForExistence(timeout: 2))
    }

    func testExportOffersSaveToFiles() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "template"]
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 15))
        app.buttons["editor-export"].tap()
        XCTAssertTrue(app.navigationBars["导出"].waitForExistence(timeout: 8))
        let files = app.buttons["export-save-files"].firstMatch
        let album = app.buttons["export-save-album"].firstMatch
        if !files.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(
            files.waitForExistence(timeout: 6) || app.buttons["存储到文件"].waitForExistence(timeout: 2),
            "missing save-to-files"
        )
        XCTAssertTrue(album.exists || app.buttons["保存到相册"].exists)
        XCTAssertTrue(app.buttons["export-share"].exists || app.buttons["系统分享"].exists)
    }

    func testInitialCanvasUsesRetinaPreviewAndUpdatesWhenRatioChanges() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "template"]
        app.launch()
        let image = app.descendants(matching: .any)["editor-canvas"]
        XCTAssertTrue(image.waitForExistence(timeout: 15))
        let ready = NSPredicate { _, _ in
            let numbers = (image.value as? String ?? "").components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
            return numbers.count >= 2 && numbers[0] >= 600 && numbers[1] >= 600
        }
        expectation(for: ready, evaluatedWith: nil)
        waitForExpectations(timeout: 10)
        let before = image.value as? String
        let ratio = app.buttons["3:4"].firstMatch
        XCTAssertTrue(ratio.waitForExistence(timeout: 5))
        ratio.tap()
        let changed = NSPredicate { _, _ in (image.value as? String) != before }
        expectation(for: changed, evaluatedWith: nil)
        waitForExpectations(timeout: 10)
    }

    func testModeCopyPreservesPhotosAndCanExportTheCopy() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "freeform"]
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 10))
        tapToolbarItem(app, id: "editor-copy-mode")
        XCTAssertTrue(app.buttons["创建副本"].waitForExistence(timeout: 6))
        app.buttons["创建副本"].tap()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 15))
        app.buttons["editor-export"].tap()
        let generate = app.buttons["export-generate"]
        XCTAssertTrue(generate.waitForExistence(timeout: 8))
        generate.tap()
        let success = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '已生成'")).firstMatch
        let actual = app.staticTexts.matching(NSPredicate(format: "(label CONTAINS 'KB' OR label CONTAINS 'MB') AND NOT label CONTAINS '预估'")).firstMatch
        XCTAssertTrue(success.waitForExistence(timeout: 15) || actual.waitForExistence(timeout: 2), app.debugDescription)
    }

    func testSingleTapSelectsAnotherPhotoWithoutEditingIt() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "template", "-sampleLayout", "g4-grid"]
        app.launch()
        let image = app.descendants(matching: .any)["editor-canvas"]
        XCTAssertTrue(image.waitForExistence(timeout: 15))
        image.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.25)).tap()
        let canvas = app.descendants(matching: .any)["editor-canvas"]
        let selectedSecond = NSPredicate { _, _ in (canvas.value as? String ?? "").contains("第 2 张") }
        expectation(for: selectedSecond, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.buttons["撤销"].isEnabled)
    }

    func testPhotoModeCardOpensSystemPickerDirectly() {
        let app = XCUIApplication()
        app.launch()
        let card = app.buttons["mode-template"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        let cancel = app.buttons["取消"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        XCTAssertTrue(app.buttons["home-pick-photos"].waitForExistence(timeout: 8))
    }

    private func tapToolbarItem(_ app: XCUIApplication, id: String) {
        let button = app.buttons[id]
        if button.waitForExistence(timeout: 2) {
            button.tap()
            return
        }
        let more = app.buttons["editor-more"]
        XCTAssertTrue(more.waitForExistence(timeout: 8), "missing \(id) and editor-more")
        more.tap()
        XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 4), "missing \(id) in more menu")
        app.buttons[id].tap()
    }

    private func tapQuickDraft(_ app: XCUIApplication) {
        let draft = app.buttons["quick-save-draft"]
        if draft.waitForExistence(timeout: 2), draft.isHittable {
            draft.tap()
            return
        }
        let more = app.buttons["quick-more"]
        XCTAssertTrue(more.waitForExistence(timeout: 10), "missing quick-save-draft and quick-more")
        more.tap()
        XCTAssertTrue(app.buttons["quick-save-draft"].waitForExistence(timeout: 4), "missing quick-save-draft in more menu")
        app.buttons["quick-save-draft"].tap()
    }

    private func tapTool(_ app: XCUIApplication, id: String, label: String) {
        let target = app.buttons[id]
        XCTAssertTrue(target.waitForExistence(timeout: 8), "missing tool " + id)
        let rail = app.descendants(matching: .any)["editor-tool-rail"]
        for attempt in 0..<16 {
            if isOnScreen(target, in: app), target.isHittable {
                target.tap()
                return
            }
            if target.frame.minX < rail.frame.minX || (target.frame.width == 0 && attempt > 3) {
                rail.coordinate(withNormalizedOffset: CGVector(dx: 0.4,dy: 0.5)).press(forDuration: 0.1, thenDragTo: rail.coordinate(withNormalizedOffset: CGVector(dx: 0.6,dy: 0.5)))
            } else {
                rail.coordinate(withNormalizedOffset: CGVector(dx: 0.6,dy: 0.5)).press(forDuration: 0.1, thenDragTo: rail.coordinate(withNormalizedOffset: CGVector(dx: 0.4,dy: 0.5)))
            }
        }
        XCTFail("could not tap tool " + id)
    }

    private func isOnScreen(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let frame = element.frame
        let bounds = app.frame
        return frame.width > 8 && frame.height > 8 && frame.minX >= -4 && frame.maxX <= bounds.width + 4
    }
}
