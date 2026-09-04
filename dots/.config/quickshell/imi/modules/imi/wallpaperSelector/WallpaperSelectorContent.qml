import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

MouseArea {
    id: root
    property int columns: Config.options.wallpaperSelector.columns || 4
    property real previewCellAspectRatio: 4 / 3
    property bool useDarkMode: Appearance.m3colors.darkmode
    property bool showControls: false
    property string source: Config.options.wallpaperSelector.wallpaperEngine.activeProject !== ""
        ? "wallpaperEngine"
        : "local"
    property string selectedResolution: "1080p"
    property bool toolbarVisible: showControls || Config.options.wallpaperSelector.showSearchbar
    property bool filterFieldFocused: false
    property string wallpaperEngineSearch: ""
    property bool workshopLoadedThisOpen: false
    property bool depthPickerOpen: false

    function loadWorkshopOnce() {
        if (source !== "wallpaperEngine" || workshopLoadedThisOpen)
            return
        workshopLoadedThisOpen = true
        WallpaperEngine.refresh()
    }

    onSourceChanged: {
        if (source === "wallpaperEngine") {
            showControls = true
            loadWorkshopOnce()
        }
    }

    Component.onCompleted: {
        if (source === "wallpaperEngine") {
            showControls = true
            loadWorkshopOnce()
        }
    }

    property var quickDirs: [
        { icon: "home",       name: "Home   ",       path: `${Directories.home}`,                alwaysVisible: Config.options.wallpaperSelector.showHomePath },
        { icon: "wallpaper",  name: "Wallpapers   ", path: `${Directories.pictures}/Wallpapers`, alwaysVisible: true },
        { icon: "imagesmode", name: "Homework   ",   path: `${Directories.pictures}/homework`,   alwaysVisible: Config.options.policies.weeb },
        { icon: "casino",     name: "Random   ",     path: `${Directories.pictures}/Random`,     alwaysVisible: true },
        { 
            icon: "image",     
            name: Config.options.wallpaperSelector.userPath?.trim().length > 0 
                ? Config.options.wallpaperSelector.userPath.split("/").filter(s => s.length > 0).pop() + "   "
                : "Custom   ",
            path: Config.options.wallpaperSelector.userPath, 
            alwaysVisible: Config.options.wallpaperSelector.userPath?.trim().length > 0 
        }
    ]

    function updateThumbnails() {
        const item = gridLoader.item;
        const totalImageMargin = (Appearance.sizes.wallpaperSelectorItemMargins + Appearance.sizes.wallpaperSelectorItemPadding) * 2;
        const cellW = item?.cellWidth ?? (wallpaperGridBackground.width / root.columns);
        const cellH = item?.cellHeight ?? (cellW / root.previewCellAspectRatio);
        const thumbnailSizeName = Images.thumbnailSizeNameForDimensions(cellW - totalImageMargin, cellH - totalImageMargin);
        Wallpapers.setDirectory(`${Directories.pictures}/Wallpapers`);
        Qt.callLater(() => Wallpapers.generateThumbnail(thumbnailSizeName));
    }

    function handleFilePasting(event) {
        const currentClipboardEntry = Cliphist.entries[0];
        if (/^\d+\tfile:\/\/\S+/.test(currentClipboardEntry)) {
            const url = StringUtils.cleanCliphistEntry(currentClipboardEntry);
            Wallpapers.setDirectory(FileUtils.trimFileProtocol(decodeURIComponent(url)));
            event.accepted = true;
        } else {
            event.accepted = false;
        }
    }

    function selectWallpaperPath(filePath) {
        if (filePath && filePath.length > 0) {
            if (GlobalStates.wallpaperSelectorTarget === "lockWall") {
                Wallpapers.select(filePath, root.useDarkMode, finalPath => {
                    // Static image lock wallpaper: clear any WE lock project.
                    Config.options.background.lockWallEngine = "";
                    Config.options.background.lockWall = finalPath;
                    GlobalStates.wallpaperSelectorTarget = "wallpaper";
                    GlobalStates.wallpaperSelectorOpen = false;
                });
            } else {
                // Stop preview FIRST so wallpaperPath reverts to the old wallpaper,
                // then the select sets confirmedPath to the new one — this causes
                // onWallpaperPathChanged to fire with the real transition animation.
                if (Config.options.background.enableWallpaperPreview)
                    Wallpapers.stopPreview();
                // Route through selectEntry (not Wallpapers.select directly) so a
                // switch from a live Wallpaper Engine wallpaper to a static image
                // still cross-fades from the engine still instead of the runtime
                // just closing. selectEntry must read the active project before
                // switchwall.sh clears it, so the transition cannot be recovered
                // after the fact.
                WallpaperEngine.selectEntry({ kind: "image", path: filePath }, root.useDarkMode);
            }
        }
    }

    function selectWallpaperEngineProject(project) {
        if (GlobalStates.wallpaperSelectorTarget === "lockWall") {
            if (!project || !project.path) return;
            // Live WE lock wallpaper: the WE surface switches to this project on
            // lock (see Background.qml weProjectPath). Keep the preview in lockWall
            // for palette generation; lockWallEngine drives the actual rendering.
            Config.options.background.lockWallEngine = project.path;
            Config.options.background.lockWall = project.preview ?? "";
            GlobalStates.wallpaperSelectorTarget = "wallpaper";
            GlobalStates.wallpaperSelectorOpen = false;
            return;
        }
        WallpaperEngine.selectEntry({ kind: "wallpaperEngine", project: project }, root.useDarkMode);
    }

    acceptedButtons: Qt.BackButton | Qt.ForwardButton
    onPressed: event => {
        if (event.button === Qt.BackButton) {
            Wallpapers.navigateBack();
        } else if (event.button === Qt.ForwardButton) {
            Wallpapers.navigateForward();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            Wallpapers.stopPreview();
            GlobalStates.wallpaperSelectorOpen = false;
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
            root.handleFilePasting(event);
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
            if (Config.options.wallpaperSelector.showSearchbar) {
                Config.options.wallpaperSelector.showSearchbar = false
                showControls = false
            } else {
                showControls = !showControls
            }
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Up) {
            Wallpapers.navigateUp();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Left) {
            Wallpapers.navigateBack();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Right) {
            Wallpapers.navigateForward();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            if (!root.filterFieldFocused) gridLoader.item?.moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            if (!root.filterFieldFocused) gridLoader.item?.moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            if (!root.filterFieldFocused) gridLoader.item?.moveSelection(-root.columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            if (!root.filterFieldFocused) gridLoader.item?.moveSelection(root.columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!root.filterFieldFocused) gridLoader.item?.activateCurrent();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace) {
            if (!root.filterFieldFocused) {
                filterField.forceActiveFocus();
            }
            event.accepted = true;
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_L) {
            addressBar.focusBreadcrumb();
            event.accepted = true;
        } else if (event.key === Qt.Key_Slash) {
            filterField.forceActiveFocus();
            event.accepted = true;
        } else {
            if (event.text.length > 0 && !root.filterFieldFocused) {
                filterField.text += event.text;
                filterField.cursorPosition = filterField.text.length;
                filterField.forceActiveFocus();
            }
            event.accepted = true;
        }
    }

    implicitHeight: mainLayout.implicitHeight
    implicitWidth: mainLayout.implicitWidth

    // The blurred body, published rather than reached into: the window owns
    // the region (it is a property of the surface) and this component owns the
    // rectangle, so the two meet at a named property instead of an id lookup
    // through the tree - the pattern the panels' `backgroundItem` pair uses.
    readonly property alias blurTarget: wallpaperGridBackground
    readonly property real blurTargetRadius: wallpaperGridBackground.radius

    StyledRectangularShadow {
        target: wallpaperGridBackground
    }

    Rectangle {
        id: wallpaperGridBackground
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        focus: true
        border.width: Appearance.borderWidth.standard
        border.color: Appearance.colors.colLayer0Border
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.screenRounding + 5

        implicitWidth: gridColumnLayout.implicitWidth
        implicitHeight: gridColumnLayout.implicitHeight

        Item {
            anchors { fill: parent; margins: Appearance.spacing.space100 }
            z: 0

            Rectangle {
                anchors.fill: parent
                radius: wallpaperGridBackground.radius - 4
                color: Appearance.colors.colLayer2
                visible: !Config.options.wallpaperSelector.showBlurBackground
            }

            StyledImage {
                id: wallpaperBgImage
                anchors.fill: parent
                visible: Config.options.wallpaperSelector.showBlurBackground
                fillMode: Image.PreserveAspectCrop
                source: Config.options.background.wallpaperPath
                cache: false
                // Bound the decode to what is drawn: without a sourceSize this
                // decoded the wallpaper at file resolution on every selector
                // open, only to be blurred at radius 48. `cache: false` above
                // means no other Image shares this request, so bounding it
                // cannot un-share a decode (the trap 33139b688 records for the
                // desktop frost, which is why Background's own request is not
                // touched from here).
                //
                // The bound is the selector's size CONSTANTS, never the item's
                // own live width/height: anchors resolve after the load starts,
                // so a bound-to-geometry sourceSize begins at 0 (= unbounded,
                // the decode this exists to remove) and then reloads once per
                // axis as the geometry lands - measured as three decodes of the
                // same file per open. The constants are known at creation and
                // stable for the window's life; they run slightly larger than
                // the item (which sits inside the card's margins), which
                // PreserveAspectCrop absorbs.
                sourceSize.width: Appearance.sizes.wallpaperSelectorWidth
                sourceSize.height: Appearance.sizes.wallpaperSelectorHeight
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: wallpaperGridBackground.width - 16
                        height: wallpaperGridBackground.height - 16
                        radius: wallpaperGridBackground.radius - 4
                    }
                }
            }

            FastBlur {
                anchors.fill: parent
                z: 0
                visible: Config.options.wallpaperSelector.showBlurBackground
                source: wallpaperBgImage
                radius: 48
                layer.enabled: visible
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: wallpaperGridBackground.width - 16
                        height: wallpaperGridBackground.height - 16
                        radius: wallpaperGridBackground.radius - 4
                    }
                }
            }
        }

        RowLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.topMargin: 0
            anchors.bottomMargin: Appearance.spacing.space100
            anchors.leftMargin: Appearance.spacing.space100
            anchors.rightMargin: Appearance.spacing.space100
            spacing: -Appearance.spacing.space50
            z: 1

            ColumnLayout {
                id: gridColumnLayout
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    id: topBar
                    Layout.fillWidth: true
                    Layout.margins: Appearance.spacing.space200
                    Layout.leftMargin: Appearance.spacing.space250
                    implicitHeight: 56

                    RowLayout {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: Appearance.spacing.space100

                        MaterialShapeWrappedMaterialSymbol {
                            wrappedShape: MaterialShape.Shape.Gem
                            text: "image"
                            iconSize: Appearance.font.pixelSize.larger
                        }

                        StyledText {
                            text: Translation.tr("Wallpaper Selector")
                            font.pixelSize: Appearance.font.pixelSize.large
                        }
                    }

                    Toolbar {
                        anchors.centerIn: parent

                        Loader {
                            active: root.source === "local"
                            visible: active
                            sourceComponent: RowLayout {
                                spacing: Appearance.spacing.space50
                                Repeater {
                                    model: root.quickDirs
                                    delegate: RippleButton {
                                        id: dirBtn
                                        required property var modelData
                                        implicitHeight: 38
                                        buttonRadius: height / 2
                                        visible: modelData.alwaysVisible
                                        toggled: Wallpapers.directory === Qt.resolvedUrl(modelData.path)
                                        colBackgroundToggled: Appearance.colors.colSecondaryContainer
                                        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                                        colRippleToggled: Appearance.colors.colSecondaryContainerActive
                                        onClicked: Wallpapers.setDirectory(modelData.path)
                                        contentItem: RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Appearance.spacing.space150
                                            anchors.rightMargin: Appearance.spacing.space150
                                            spacing: Appearance.spacing.space100
                                            MaterialSymbol {
                                                text: dirBtn.modelData.icon
                                                iconSize: Appearance.font.pixelSize.larger
                                                color: dirBtn.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                                fill: dirBtn.toggled ? 1 : 0
                                            }
                                            StyledText {
                                                text: dirBtn.modelData.name
                                                color: dirBtn.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Loader {
<<<<<<< ours
                            active: root.source !== "local" && root.source !== "wallpaperEngine"
=======
                            active: root.source === "unsplash" || root.source === "pexels"
>>>>>>> theirs
                            visible: active
                            sourceComponent: RowLayout {
                                spacing: Appearance.spacing.space50
                                Repeater {
                                    model: ["1080p", "2K", "4K"]
                                    delegate: RippleButton {
                                        required property string modelData
                                        implicitHeight: 38
                                        buttonRadius: height / 2
                                        toggled: root.selectedResolution === modelData
                                        colBackgroundToggled: Appearance.colors.colSecondaryContainer
                                        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                                        colRippleToggled: Appearance.colors.colSecondaryContainerActive
                                        onClicked: root.selectedResolution = modelData
                                        contentItem: StyledText {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: parent.toggled
                                                ? Appearance.colors.colOnSecondaryContainer
                                                : Appearance.colors.colOnLayer2
                                        }
                                    }
                                }
                            }
                        }

                        Loader {
                            active: root.source === "wallpaperEngine"
                            visible: active
                            sourceComponent: RowLayout {
                                spacing: Appearance.spacing.space100

                                StyledText {
                                    text: Translation.tr("Steam Workshop")
                                    color: Appearance.colors.colOnLayer2
                                }

                                StyledComboBox {
                                    implicitWidth: 92
                                    model: [
                                        { value: 24, displayName: "24 FPS" },
                                        { value: 30, displayName: "30 FPS" },
                                        { value: 60, displayName: "60 FPS" }
                                    ]
                                    textRole: "displayName"
                                    Component.onCompleted: {
                                        const configured = Config.options.wallpaperSelector.wallpaperEngine.fps;
                                        currentIndex = configured === 24 ? 0 : configured === 60 ? 2 : 1;
                                    }
                                    onActivated: index => Config.options.wallpaperSelector.wallpaperEngine.fps = model[index].value
                                }

                                StyledComboBox {
                                    implicitWidth: 90
                                    model: [
                                        { value: "fill", displayName: Translation.tr("Fill") },
                                        { value: "fit", displayName: Translation.tr("Fit") },
                                        { value: "stretch", displayName: Translation.tr("Stretch") }
                                    ]
                                    textRole: "displayName"
                                    Component.onCompleted: {
                                        const configured = Config.options.wallpaperSelector.wallpaperEngine.scaling;
                                        currentIndex = configured === "fit" ? 1 : configured === "stretch" ? 2 : 0;
                                    }
                                    onActivated: index => Config.options.wallpaperSelector.wallpaperEngine.scaling = model[index].value
                                }

                                // Which screen plays the sound. Offered beside
                                // the volume button because that is where the
                                // user turns sound on, and only where the
                                // question exists: one screen, or muted, and
                                // there is nothing to choose.
                                //
                                // There is one renderer per output, so before
                                // this the audio played once per monitor (#338).
                                StyledComboBox {
                                    id: audioOutputBox
                                    implicitWidth: 116
                                    visible: !Config.options.wallpaperSelector.wallpaperEngine.silent
                                        && (Quickshell.screens?.length ?? 0) > 1

                                    readonly property var outputs: [{
                                        value: "",
                                        displayName: Translation.tr("Auto")
                                    }].concat((Quickshell.screens ?? []).map(screen => ({
                                        value: screen.name,
                                        displayName: screen.name
                                    })))

                                    model: audioOutputBox.outputs
                                    textRole: "displayName"
                                    // Bound rather than set once on completion:
                                    // a screen can arrive or leave while this is
                                    // on screen, and the neighbours above only
                                    // get away with Component.onCompleted
                                    // because their options are a fixed list.
                                    currentIndex: Math.max(0, audioOutputBox.outputs
                                        .findIndex(output => output.value
                                            === (Config.options.wallpaperSelector.wallpaperEngine.audioMonitor ?? "")))
                                    onActivated: index =>
                                        Config.options.wallpaperSelector.wallpaperEngine.audioMonitor
                                            = audioOutputBox.outputs[index].value

                                    StyledToolTip {
                                        text: Translation.tr("Screen that plays the wallpaper's sound")
                                    }
                                }

                                RippleButton {
                                    implicitWidth: 38
                                    implicitHeight: 38
                                    buttonRadius: height / 2
                                    toggled: Config.options.wallpaperSelector.wallpaperEngine.silent
                                    onClicked: Config.options.wallpaperSelector.wallpaperEngine.silent = !Config.options.wallpaperSelector.wallpaperEngine.silent
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: Config.options.wallpaperSelector.wallpaperEngine.silent ? "volume_off" : "volume_up"
                                        color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                                    }
                                    StyledToolTip { text: Translation.tr("Wallpaper audio") }
                                }
                            }
                        }
                    }

                    RowLayout {
                        anchors {
                            right: parent.right
                            rightMargin: Appearance.spacing.space100
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: Appearance.spacing.space100

                        StyledComboBox {
                            id: sourceCombo
                            implicitWidth: 168
                            model: [
                                { value: "local",     displayName: Translation.tr("Local") },
                                { value: "wallpaperEngine", displayName: Translation.tr("Wallpaper Engine") },
                                { value: "wallhaven", displayName: Translation.tr("Wallhaven") },
                                { value: "unsplash",  displayName: Translation.tr("Unsplash") },
                                { value: "pexels",    displayName: Translation.tr("Pexels") },
                            ]
                            textRole: "displayName"
                            currentIndex: root.source === "wallpaperEngine" ? 1
                                : root.source === "wallhaven" ? 2
                                : root.source === "unsplash" ? 3
                                : root.source === "pexels" ? 4
                                : 0
                            onActivated: index => {
                                root.source = model[index].value
                                root.forceActiveFocus()
                            }
                        }

                        RippleButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: height / 2
                            toggled: root.toolbarVisible
                            colBackground: Appearance.colors.colSecondaryContainer
                            onClicked: {
                                if (Config.options.wallpaperSelector.showSearchbar) {
                                    Config.options.wallpaperSelector.showSearchbar = false
                                    showControls = false
                                } else {
                                    showControls = !showControls
                                }
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "search"
                                iconSize: Appearance.font.pixelSize.larger
                                color: root.toolbarVisible
                                    ? Appearance.colors.colOnPrimary
                                    : Appearance.colors.colOnSecondaryContainer
                            }
                            StyledToolTip {
                                text: Translation.tr("Toggle search toolbar (Ctrl+F)")
                            }
                        }
                    }
                }

                Item {
                    id: gridDisplayRegion
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Loader {
                        id: depthPickerLoader
                        anchors.fill: parent
                        // Loaded on demand, and it is what sets ClockDepth.picking:
                        // the cache is not queried at all until either this is open
                        // or the feature is switched on, so a machine that has never
                        // used depth spawns nothing for it.
                        active: root.depthPickerOpen
                        visible: active
                        z: 3
                        sourceComponent: ClockDepthPicker {
                            // The preview has to be cropped the way the desktop
                            // crops it, or the user accepts a mask against a
                            // frame the wallpaper is never shown in.
                            screenAspect: Screen.height > 0
                                ? Screen.width / Screen.height
                                : 16 / 9
                            Component.onCompleted: ClockDepth.picking = true
                            Component.onDestruction: ClockDepth.picking = false
                            onCloseRequested: root.depthPickerOpen = false
                            // The mode is armed BEFORE either surface closes.
                            // ClockDepth keeps its cache answers only while
                            // something is watching, and destroying the picker
                            // drops its claim - so arming afterwards would let
                            // the service forget the candidate in between and
                            // re-query for it from an empty state.
                            onSelectOnDesktopRequested: {
                                GlobalStates.clockDepthSelectOpen = true;
                                root.depthPickerOpen = false;
                                GlobalStates.wallpaperSelectorOpen = false;
                            }
                        }
                    }

                    Loader {
                        id: gridLoader
                        anchors.fill: parent
<<<<<<< ours
                        sourceComponent: root.source === "local"
                            ? localGridComponent
                            : root.source === "wallpaperEngine"
                                ? wallpaperEngineGridComponent
                                : onlineGridComponent
=======
                        sourceComponent: root.source === "local" ? localGridComponent
                            : root.source === "wallhaven" ? wallhavenGridComponent
                            : onlineGridComponent
>>>>>>> theirs
                    }

                    Component {
                        id: localGridComponent
                        LocalWallpaperGrid {
                            columns: root.columns
                            previewCellAspectRatio: root.previewCellAspectRatio
                            onWallpaperSelected: path => root.selectWallpaperPath(path)
                        }
                    }

                    Component {
<<<<<<< ours
                        id: wallpaperEngineGridComponent
                        WallpaperEngineGrid {
                            columns: root.columns
                            previewCellAspectRatio: root.previewCellAspectRatio
                            searchQuery: root.wallpaperEngineSearch
                            onProjectSelected: project => root.selectWallpaperEngineProject(project)
=======
                        id: wallhavenGridComponent
                        WallhavenSearchGrid {
                            columns: root.columns
                            previewCellAspectRatio: root.previewCellAspectRatio
                            useDarkMode: root.useDarkMode
                            onWallpaperApplied: {
                                if (Config.options.wallpaperSelector.closeAfterSelection)
                                    GlobalStates.wallpaperSelectorOpen = false;
                            }
>>>>>>> theirs
                        }
                    }

                    Component {
                        id: onlineGridComponent
                        OnlineWallpaperGrid {
                            provider: root.source
                            resolution: root.selectedResolution
                            onWallpaperSelected: path => root.selectWallpaperPath(path)
                            onUpdateThumbnailsRequested: root.updateThumbnails()
                        }
                    }

                    Row {
                        id: extraOptions
                        anchors {
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                            bottomMargin: Appearance.spacing.space100
                        }
                        spacing: Appearance.spacing.space100
                        z: root.toolbarVisible ? 2 : -1
                        opacity: root.toolbarVisible ? 1 : 0
                        transform: Translate {
                            y: root.toolbarVisible ? 0 : 20
                            Behavior on y {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }

                        Loader {
                            active: root.source === "local"
                            visible: active
                            sourceComponent: Toolbar {
                                IconToolbarButton {
                                    implicitWidth: height
                                    onClicked: {
                                        Wallpapers.openFallbackPicker(root.useDarkMode);
                                        GlobalStates.wallpaperSelectorOpen = false;
                                    }
                                    altAction: () => {
                                        Wallpapers.openFallbackPicker(root.useDarkMode);
                                        GlobalStates.wallpaperSelectorOpen = false;
                                        Config.options.wallpaperSelector.useSystemFileDialog = true;
                                    }
                                    text: "open_in_new"
                                }
                                IconToolbarButton {
                                    implicitWidth: height
                                    onClicked: Wallpapers.randomFromCurrentFolder()
                                    text: "ifl"
                                }
                                IconToolbarButton {
                                    implicitWidth: height
                                    onClicked: root.useDarkMode = !root.useDarkMode
                                    text: root.useDarkMode ? "dark_mode" : "light_mode"
                                }
                                IconToolbarButton {
                                    implicitWidth: height
                                    onClicked: root.updateThumbnails()
                                    text: "reset_image"
                                }
                                IconToolbarButton {
                                    implicitWidth: height
                                    // The only way into segmentation. Nothing
                                    // else in the shell can start a run: it
                                    // costs seconds and a gigabyte, and it
                                    // produces an unusable mask often enough
                                    // that a human has to look at the result.
                                    onClicked: root.depthPickerOpen = !root.depthPickerOpen
                                    toggled: root.depthPickerOpen
                                    text: "layers"
                                    StyledToolTip {
                                        text: Translation.tr("Put the widgets behind this wallpaper's subject")
                                    }
                                }
                                ToolbarTextField {
                                    id: filterField
                                    placeholderText: focus
                                        ? Translation.tr("Search wallpapers")
                                        : Translation.tr("Search wallpapers")
                                    clip: true
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    onTextChanged: Wallpapers.searchQuery = text
                                    onActiveFocusChanged: root.filterFieldFocused = activeFocus
                                    Keys.onPressed: event => {
                                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                                            root.handleFilePasting(event);
                                            event.accepted = true;
                                            return;
                                        }
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            event.accepted = true;
                                            return;
                                        }
                                        if (text.length !== 0) {
                                            if (event.key === Qt.Key_Down) { event.accepted = true; return; }
                                            if (event.key === Qt.Key_Up)   { event.accepted = true; return; }
                                        }
                                        event.accepted = false;
                                    }
                                }
                            }
                        }

                        Loader {
<<<<<<< ours
                            active: root.source === "wallpaperEngine"
                            visible: active
                            sourceComponent: Toolbar {
                                ToolbarTextField {
                                    placeholderText: Translation.tr("Search Wallpaper Engine projects")
                                    clip: true
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    onTextChanged: root.wallpaperEngineSearch = text
                                    onActiveFocusChanged: root.filterFieldFocused = activeFocus
                                }
                                IconToolbarButton {
                                    implicitWidth: height
                                    // The same way in as the local toolbar's -
                                    // and the only one this tab had none of.
                                    // The depth service has asked about live
                                    // projects since spec §8 landed (it asks
                                    // about the wallpaper ON SCREEN, which is
                                    // the project's still whenever a project
                                    // is live), but the picker's button only
                                    // existed on the Local tab, so a user
                                    // whose wallpaper came from THIS grid had
                                    // no path into segmentation at all.
                                    onClicked: root.depthPickerOpen = !root.depthPickerOpen
                                    toggled: root.depthPickerOpen
                                    text: "layers"
                                    StyledToolTip {
                                        text: Translation.tr("Put the widgets behind this wallpaper's subject")
                                    }
                                }
                                IconToolbarButton {
                                    text: "refresh"
                                    enabled: !WallpaperEngine.loading
                                    onClicked: WallpaperEngine.refresh()
                                }
                                IconToolbarButton {
                                    text: "stop_circle"
                                    enabled: Config.options.wallpaperSelector.wallpaperEngine.activeProject !== ""
                                    onClicked: WallpaperEngine.stop()
                                    StyledToolTip { text: Translation.tr("Clear Wallpaper Engine selection") }
                                }
                            }
                        }

                        Loader {
                            active: root.source !== "local" && root.source !== "wallpaperEngine"
=======
                            active: root.source === "unsplash" || root.source === "pexels"
>>>>>>> theirs
                            visible: active
                            sourceComponent: Toolbar {
                                ToolbarTextField {
                                    id: onlineSearchField
                                    placeholderText: Translation.tr("Search online wallpapers")
                                    clip: true
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    onTextChanged: OnlineWallpapers.query = text
                                    onAccepted: OnlineWallpapers.fetch()
                                    onActiveFocusChanged: root.filterFieldFocused = activeFocus
                                    Connections {
                                        target: GlobalStates
                                        function onWallpaperSelectorOpenChanged() {
                                            if (!GlobalStates.wallpaperSelectorOpen) onlineSearchField.text = ""
                                        }
                                    }
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            event.accepted = true;
                                            return;
                                        }
                                        event.accepted = false;
                                    }
                                }
                                IconToolbarButton {
                                    implicitWidth: height
                                    text: "refresh"
                                    onClicked: OnlineWallpapers.fetch()
                                }
                            }
                        }

                        Loader {
                            active: root.source === "wallhaven"
                            visible: active
                            sourceComponent: Toolbar {
                                id: wallhavenToolbar

                                // Broad color families. Each ORs several wallhaven palette colors (the API
                                // accepts a comma-separated list) so one swatch = a wide range of wallpapers.
                                // `hex` is the display swatch; `q` is the comma-joined wallhaven colors value.
                                readonly property var colorGroups: [
                                    { hex: "cc0000", q: "660000,990000,cc0000,cc3333" },        // Red
                                    { hex: "ff6600", q: "ffcc33,ff9900,ff6600" },               // Orange
                                    { hex: "cccc33", q: "666600,999900,cccc33,ffff00" },        // Yellow
                                    { hex: "669900", q: "77cc33,669900,336600" },               // Green
                                    { hex: "66cccc", q: "66cccc,0099cc" },                      // Teal
                                    { hex: "0066cc", q: "0066cc,0099cc,333399" },               // Blue
                                    { hex: "663399", q: "ea4c88,993399,663399,333399" },        // Purple / pink
                                    { hex: "996633", q: "cc6633,996633,663300" },               // Brown
                                    { hex: "999999", q: "000000,999999,cccccc,ffffff,424153" }  // Neutral
                                ]

                                // Display hex of the currently-active family ("" if none) — drives the button color
                                readonly property string activeHex: {
                                    for (let i = 0; i < colorGroups.length; i++)
                                        if (colorGroups[i].q === WallhavenSearch.colors) return colorGroups[i].hex
                                    return ""
                                }

                                // Black/white that reads on a given hex (relative luminance)
                                function contrastColor(hex) {
                                    if (!hex || hex.length < 6) return Appearance.colors.colOnLayer1
                                    const r = parseInt(hex.substr(0, 2), 16)
                                    const g = parseInt(hex.substr(2, 2), 16)
                                    const b = parseInt(hex.substr(4, 2), 16)
                                    return (0.299 * r + 0.587 * g + 0.114 * b) > 140 ? "#000000" : "#ffffff"
                                }

                                Timer {
                                    id: searchDebounce
                                    interval: 500
                                    onTriggered: WallhavenSearch.search(wallhavenSearchField.text, 1)
                                }

                                ToolbarTextField {
                                    id: wallhavenSearchField
                                    text: WallhavenSearch.currentQuery
                                    placeholderText: Translation.tr("Search Wallhaven...")
                                    Layout.preferredWidth: 220
                                    onTextChanged: searchDebounce.restart()
                                    onAccepted: {
                                        searchDebounce.stop()
                                        WallhavenSearch.search(text, 1)
                                    }
                                    onActiveFocusChanged: root.filterFieldFocused = activeFocus
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            event.accepted = true
                                            return
                                        }
                                        event.accepted = false
                                    }
                                }

                                // Pagination
                                RowLayout {
                                    visible: WallhavenSearch.currentResults.length > 0
                                    spacing: 4

                                    IconToolbarButton {
                                        implicitWidth: height
                                        text: "navigate_before"
                                        enabled: !WallhavenSearch.fetching && WallhavenSearch.currentPage > 1
                                        onClicked: WallhavenSearch.previousPage()
                                    }

                                    StyledText {
                                        text: WallhavenSearch.currentPage + " / " + WallhavenSearch.lastPage
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnLayer1
                                    }

                                    IconToolbarButton {
                                        implicitWidth: height
                                        text: "navigate_next"
                                        enabled: !WallhavenSearch.fetching && WallhavenSearch.currentPage < WallhavenSearch.lastPage
                                        onClicked: WallhavenSearch.nextPage()
                                    }
                                }

                                IconToolbarButton {
                                    id: paletteButton
                                    implicitWidth: height
                                    text: "palette"
                                    toggled: colorMenu.visible || WallhavenSearch.colors.length > 0
                                    // Reflect the active color family on the button itself
                                    colBackgroundToggled: wallhavenToolbar.activeHex.length > 0 ? ("#" + wallhavenToolbar.activeHex) : Appearance.colors.colSecondaryContainer
                                    colBackgroundToggledHover: wallhavenToolbar.activeHex.length > 0 ? ("#" + wallhavenToolbar.activeHex) : Appearance.colors.colSecondaryContainerHover
                                    colText: wallhavenToolbar.activeHex.length > 0
                                        ? wallhavenToolbar.contrastColor(wallhavenToolbar.activeHex)
                                        : (toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant)
                                    onClicked: colorMenu.visible ? colorMenu.close() : colorMenu.open()
                                    StyledToolTip {
                                        text: Translation.tr("Filter by color")
                                    }

                                    // Drop-down color grid (opens upward since the toolbar sits at the bottom)
                                    Popup {
                                        id: colorMenu
                                        y: -height - 6
                                        x: paletteButton.width - width
                                        padding: 10
                                        modal: false
                                        focus: true
                                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                                        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 100 } }
                                        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }

                                        background: Rectangle {
                                            // m3 token is opaque (colLayer1 is alpha-blended → looked see-through)
                                            color: Appearance.m3colors.m3surfaceContainerHigh
                                            radius: Appearance.rounding.normal
                                            border.width: 1
                                            border.color: Appearance.colors.colLayer0Border
                                        }

                                        contentItem: ColumnLayout {
                                            spacing: 8

                                            RowLayout {
                                                Layout.fillWidth: true
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: Translation.tr("Filter by color")
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                    color: Appearance.colors.colSubtext
                                                }
                                                // Clear / any-color
                                                RippleButton {
                                                    visible: WallhavenSearch.colors.length > 0
                                                    implicitHeight: 24
                                                    leftPadding: 8
                                                    rightPadding: 8
                                                    buttonRadius: height / 2
                                                    onClicked: { WallhavenSearch.setColor(""); colorMenu.close() }
                                                    contentItem: StyledText {
                                                        text: Translation.tr("Clear")
                                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                                        color: Appearance.colors.colOnLayer1
                                                    }
                                                }
                                            }

                                            Grid {
                                                columns: 3
                                                spacing: 8
                                                Repeater {
                                                    model: wallhavenToolbar.colorGroups
                                                    delegate: Rectangle {
                                                        required property var modelData
                                                        width: 44; height: 44; radius: Appearance.rounding.small
                                                        color: "#" + modelData.hex
                                                        border.width: WallhavenSearch.colors === modelData.q ? 3 : 1
                                                        border.color: WallhavenSearch.colors === modelData.q ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { WallhavenSearch.setColor(parent.modelData.q); colorMenu.close() }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                IconToolbarButton {
                                    implicitWidth: height
                                    text: "tune"
                                    onClicked: { if (gridLoader.item) gridLoader.item.showSettings = true }
                                    StyledToolTip {
                                        text: Translation.tr("Wallhaven search settings")
                                    }
                                }

                                IconToolbarButton {
                                    implicitWidth: height
                                    text: root.useDarkMode ? "dark_mode" : "light_mode"
                                    onClicked: root.useDarkMode = !root.useDarkMode
                                    StyledToolTip {
                                        text: Translation.tr("Toggle light/dark mode for applied wallpaper")
                                    }
                                }

                                IconToolbarButton {
                                    implicitWidth: height
                                    text: "refresh"
                                    onClicked: WallhavenSearch.search(WallhavenSearch.currentQuery, 1)
                                    StyledToolTip {
                                        text: Translation.tr("Refresh search results")
                                    }
                                }
                            }
                        }

                        ToolbarPairedFab {
                            iconText: "close"
                            onClicked: {
                                Wallpapers.stopPreview();
                                GlobalStates.wallpaperSelectorOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onWallpaperSelectorOpenChanged() {
            if (GlobalStates.wallpaperSelectorOpen && monitorIsFocused) {
                if (root.source === "wallpaperEngine") {
                    root.forceActiveFocus();
                } else if (root.source === "local")
                    filterField.forceActiveFocus()
                else
                    root.forceActiveFocus()
            } else if (!GlobalStates.wallpaperSelectorOpen) {
                Wallpapers.stopPreview();
            }
        }
    }

    Connections {
        target: Wallpapers
        function onChanged() {
            if (Config.options.wallpaperSelector.closeAfterSelection)
                GlobalStates.wallpaperSelectorOpen = false;
        }
    }

    Connections {
        target: WallpaperEngine
        function onApplied() {
            if (Config.options.wallpaperSelector.closeAfterSelection)
                GlobalStates.wallpaperSelectorOpen = false;
        }
    }
}
