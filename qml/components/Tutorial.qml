import QtQuick 2.12
import QtQuick.Layouts 1.12
import Lomiri.Components 1.3
import Lomiri.Components.Themes 1.3

/*
 * The guided tour of the launcher, shown at the first run and on request from
 * the help page ("How to use").
 *
 * The tour dims the whole application and lights up one of its parts at a time:
 * the search bar, the widgets, the favorite apps, the application list, the bar
 * which moves from one page to the other, and the configuration bar a swipe up
 * from the bottom of the screen reveals.
 *
 * A step names the elements it points at, and the tour resolves those names
 * while it runs: "main.bottomBar" for the items Main.qml hands to this
 * component, or a key of the `tutorialTargets` map a page exposes to the tour
 * (see pages/Home.qml). A step whose elements no page offers is skipped, so a
 * page which exposes no `tutorialTargets` still gets the steps which need
 * nothing; an element which is offered but empty, as a page without any
 * favorite app yet, keeps its step and shows it without highlight.
 *
 * Main.qml owns `visible`: this component only asks for the tour to end, with
 * `finished()`.
 */
Item {
    id: tutorial

    /// The bar at the bottom of the launcher, which moves between pages
    property Item bottomBar: null
    /// The SwipeView of the pages, and the Repeater holding their loaders
    property Item pageView: null
    property Item pageRepeater: null

    /// Emitted when the user leaves the tour, on the skip button or the last step
    signal finished()

    /// The steps of the tour, built when it starts, see buildSteps()
    property var steps: []
    property int stepIndex: 0

    /// The elements of the current step the highlight is drawn around
    property var targets: []

    readonly property var currentStep: stepIndex < steps.length ? steps[stepIndex] : null
    readonly property bool lastStep: stepIndex >= steps.length - 1
    /// A step shows a frame only while it has something to light up
    readonly property bool highlighted: holeHeight > units.gu(1)
    readonly property bool swipeUpStep: currentStep !== null && currentStep.key === "configBar"

    /// The part of the screen the tour explains, in the coordinates of the tour
    property real holeX: 0
    property real holeY: 0
    property real holeWidth: 0
    property real holeHeight: 0
    /// Where the card with the text of the step sits
    property real cardY: 0

    visible: false
    // Main.qml puts it last, above the pages, the bar and the dialogs, none of
    // which ask for a z of their own
    z: 1000

    onVisibleChanged: {
        if (visible) {
            // the tour explains the launcher from its first page
            if (pageView) {
                pageView.currentIndex = 0
            }
            steps = buildSteps()
            showStep(0, false)
        } else {
            steps = []
            stepIndex = 0
            targets = []
        }
    }

    /* ************************************ WHAT THE TOUR SAYS ************************************ */

    /*
     * A step is a title, a text, and optionally the elements it points at under
     * `elements`: one name or a list of names. "main.bottomBar" is an element of
     * Main.qml, any other name is a key of the `tutorialTargets` map of the page
     * shown by the SwipeView. A `key` tells the steps which need it apart.
     */
    function buildSteps() {
        return [
            {
                title: i18n.tr("Welcome to Modular Launcher"),
                text: i18n.tr("Every screen of this launcher is a page you add and configure yourself. This tour shows the parts of the Home page. You can leave it at any time and find it again in the help.")
            },
            {
                elements: "search",
                title: i18n.tr("The search bar"),
                text: i18n.tr("Type to filter the applications of this page. The same field finds your contacts and calculates an expression. The icon on its right opens a web search, with the engine chosen in the settings of this page.")
            },
            {
                elements: ["widgets", "widgetsMore"],
                title: i18n.tr("The widgets"),
                text: i18n.tr("The clock, the weather, the alarms, the last calls, the last messages and the events live here. Press and hold a widget to open its own settings, and choose the ones to show in the settings of this page.")
            },
            {
                elements: "favorites",
                title: i18n.tr("The favorite applications"),
                text: i18n.tr("The applications you choose stay at the top of this page, above the others. Add, remove and reorder them in the settings of this page.")
            },
            {
                elements: "apps",
                title: i18n.tr("The applications"),
                text: i18n.tr("All the applications installed on the device, and the custom icons you create. Touch one to launch it, press and hold it to uninstall it or to take a custom icon off, and pull down to refresh the list.")
            },
            {
                key: "navigation",
                elements: "main.bottomBar",
                title: i18n.tr("Moving between pages"),
                text: i18n.tr("The bar at the bottom shows one icon per page of the launcher. Touch an icon to jump to that page, or swipe left and right, on this bar or on the page itself, to go from one page to the next.")
            },
            {
                key: "configBar",
                elements: "main.bottomBar",
                title: i18n.tr("The configuration bar"),
                text: i18n.tr("Swipe up from the bottom of the screen to open it: add a custom icon, manage the pages, configure the launcher and its autostart, open the help and the about page.")
            },
            {
                key: "managePages",
                title: i18n.tr("Configuring the pages"),
                text: i18n.tr("In that bar, Manage pages opens the list of your pages. The plus sign adds one: another home, a clock, a calendar, photos, music, videos, news feeds, tasks, folders or your Nextcloud files. Touching a page opens its own settings. Enjoy your launcher.")
            }
        ];
    }

    /* ************************************ THE STEP TO SHOW ************************************ */

    /// Shows the step at `index`, or the closest one which has elements to show
    function showStep(index, backwards) {
        while (index >= 0 && index < steps.length && !stepOffersElements(steps[index])) {
            index += backwards ? -1 : 1;
        }
        if (index < 0 || index >= steps.length) {
            tutorial.finished();
            return;
        }

        stepIndex = index;
        targets = resolveItems(steps[index]);
        for (var i = 0; i < targets.length; i++) {
            scrollIntoView(targets[i]);
        }
        updateGeometry();
    }

    function next() {
        showStep(stepIndex + 1, false);
    }

    function previous() {
        showStep(stepIndex - 1, true);
    }

    /*
     * Follows what the tour explains: a page is scrolled, an application list
     * fills itself, the device is turned around. A step which found nothing
     * when it started may find its elements once the page is built.
     */
    function refresh() {
        if (targets.length === 0 && currentStep && resolveNames(currentStep).length > 0) {
            targets = resolveItems(currentStep);
            for (var i = 0; i < targets.length; i++) {
                scrollIntoView(targets[i]);
            }
        }
        updateGeometry();
    }

    /// The names of the elements a step points at, empty when it needs none
    function resolveNames(step) {
        if (!step || !step.elements) {
            return [];
        }
        return typeof step.elements === "string" ? [step.elements] : step.elements;
    }

    /*
     * Whether the shown page and Main.qml offer what a step points at. A step
     * which points at nothing tells about the launcher itself and always
     * applies; a step whose elements nobody offers is worth skipping.
     */
    function stepOffersElements(step) {
        var names = resolveNames(step);
        if (names.length === 0) {
            return true;
        }
        for (var i = 0; i < names.length; i++) {
            if (namedElement(names[i])) {
                return true;
            }
        }
        return false;
    }

    /// The page shown by the SwipeView, that is the content of its loader
    function currentPage() {
        try {
            var loader = pageRepeater.itemAt(pageView.currentIndex);
            return loader ? loader.item : null;
        } catch (error) {
            // the view is not in the state the tour expects: nothing to explain
            return null;
        }
    }

    /// The elements the shown page offers to the tour, see pages/Home.qml
    function pageElements() {
        try {
            var elements = currentPage().tutorialTargets;
            return elements ? elements : {};
        } catch (error) {
            // a page without `tutorialTargets` explains itself
            return {};
        }
    }

    /// The element a name points at, null when nothing is offered under it
    function namedElement(name) {
        if (name === "main.bottomBar") {
            return bottomBar;
        }
        if (name.indexOf("main.") === 0) {
            // an element Main.qml does not give cannot be lit up
            return null;
        }
        var elements = pageElements();
        return name in elements ? elements[name] : null;
    }

    /// The elements of a step which are on the screen and worth a frame
    function resolveItems(step) {
        var names = resolveNames(step);
        var items = [];
        for (var i = 0; i < names.length; i++) {
            var item = namedElement(names[i]);
            if (item && item.visible && item.width > 0 && item.height > 0) {
                items.push(item);
            }
        }
        return items;
    }

    /* ************************************ THE PART IT LIGHTS UP ************************************ */

    /*
     * The lowest line the tour draws above: the bottom of the screen, minus the
     * bar at the bottom of the launcher, so the card never covers the pages.
     */
    function usableLimit() {
        if (bottomBar && bottomBar.visible) {
            return Math.max(0, height - bottomBar.height);
        }
        return height;
    }

    /*
     * The lowest line an element is measured against. The bar at the bottom is
     * the subject of two steps of the tour, so it is lit up like anything else;
     * everything else stops above it.
     */
    function bottomLimitFor(item) {
        var it = item;
        while (it) {
            if (it === bottomBar) {
                return height;
            }
            it = it.parent;
        }
        return usableLimit();
    }

    /// Brings an element inside the part of the screen the tour can use
    function scrollIntoView(item) {
        var flick = scrollableParent(item);
        if (!flick || item.height >= usableLimit()) {
            return;
        }
        try {
            var top = item.mapToItem(tutorial, 0, 0).y;
            var bottom = top + item.height;
            var gap = units.gu(1);
            var limit = bottomLimitFor(item) - gap;

            var move = 0;
            if (top < gap) {
                move = gap - top;
            } else if (bottom > limit) {
                move = limit - bottom;
            }
            if (move !== 0) {
                var y = flick.contentY - move;
                flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, y));
            }
        } catch (error) {
            // an element which cannot be followed is shown as it is
        }
    }

    function scrollableParent(item) {
        var parent = item.parent;
        while (parent) {
            if (typeof parent.contentY !== "undefined" && typeof parent.contentHeight !== "undefined") {
                return parent;
            }
            parent = parent.parent;
        }
        return null;
    }

    /*
     * Recomputes the frame and the place of the card. The tour keeps calling it
     * while it is shown: a page is scrolled, an application list fills itself,
     * the device is turned around, and the elements move.
     */
    function updateGeometry() {
        if (width <= 0 || height <= 0) {
            // asked where to draw before it has a size of its own: the timer
            // called while it is shown will ask again once the page has one
            return;
        }
        var left = 0, top = 0, right = 0, bottom = 0;
        var lit = false;

        for (var i = 0; i < targets.length; i++) {
            try {
                var pos = targets[i].mapToItem(tutorial, 0, 0);
                var itemTop = Math.max(pos.y, 0);
                var itemBottom = Math.min(pos.y + targets[i].height, bottomLimitFor(targets[i]));
            } catch (error) {
                continue;
            }
            if (itemBottom - itemTop <= 0) {
                // completely out of the part of the screen the tour can use
                continue;
            }
            if (lit) {
                left = Math.min(left, pos.x);
                top = Math.min(top, itemTop);
                right = Math.max(right, pos.x + targets[i].width);
                bottom = Math.max(bottom, itemBottom);
            } else {
                left = pos.x;
                top = itemTop;
                right = pos.x + targets[i].width;
                bottom = itemBottom;
                lit = true;
            }
        }

        if (lit) {
            var margin = units.gu(0.5);
            holeX = Math.max(0, left - margin);
            holeY = Math.max(0, top - margin);
            holeWidth = Math.max(0, Math.min(width - holeX, right + margin - holeX));
            holeHeight = Math.max(0, Math.min(height - holeY, bottom + margin - holeY));
        } else {
            holeX = 0;
            holeY = 0;
            holeWidth = 0;
            holeHeight = 0;
        }

        if (holeWidth <= units.gu(1) || holeHeight <= units.gu(1)) {
            // too small to be worth a frame of its own
            holeWidth = 0;
            holeHeight = 0;
        }

        // the card goes below what it explains, above it when it does not fit,
        // and in the middle when there is nothing to explain around
        var bottomLimit = usableLimit() - units.gu(1);
        var arrowRoom = swipeUpStep && highlighted ? arrow.height + units.gu(0.5) : 0;
        if (highlighted && bottomLimit - (holeY + holeHeight) > card.height + units.gu(1)) {
            cardY = holeY + holeHeight + units.gu(1);
        } else if (highlighted && holeY - arrowRoom > card.height + units.gu(1)) {
            cardY = holeY - arrowRoom - card.height - units.gu(1);
        } else {
            cardY = (bottomLimit - card.height) / 2;
        }
        cardY = Math.max(units.gu(1), Math.min(bottomLimit - card.height, cardY));
    }

    // the touches are swallowed: the tour itself must not drive the launcher
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel.accepted = true
    }

    // the dim, all around the part the tour explains
    Rectangle {
        width: tutorial.width
        height: tutorial.holeY
        color: "#CC000000"
    }

    Rectangle {
        y: tutorial.holeY + tutorial.holeHeight
        width: tutorial.width
        height: Math.max(0, tutorial.height - tutorial.holeY - tutorial.holeHeight)
        color: "#CC000000"
    }

    Rectangle {
        y: tutorial.holeY
        width: tutorial.holeX
        height: tutorial.holeHeight
        color: "#CC000000"
    }

    Rectangle {
        x: tutorial.holeX + tutorial.holeWidth
        y: tutorial.holeY
        width: Math.max(0, tutorial.width - tutorial.holeX - tutorial.holeWidth)
        height: tutorial.holeHeight
        color: "#CC000000"
    }

    Rectangle {
        visible: tutorial.highlighted
        x: tutorial.holeX
        y: tutorial.holeY
        width: tutorial.holeWidth
        height: tutorial.holeHeight
        radius: units.gu(1)
        color: "transparent"
        border.width: units.gu(0.2)
        border.color: "#E95420"
    }

    /*
     * The swipe up cannot be shown with an element of the interface, so the
     * gesture itself is animated above the bar it opens.
     */
    Item {
        id: arrow
        visible: tutorial.highlighted && tutorial.swipeUpStep
        x: (tutorial.width - width) / 2
        y: Math.max(0, tutorial.holeY - height - units.gu(0.5))
        width: units.gu(3)
        height: units.gu(4)

        // no vertical anchor: its own animation moves it up and down
        Icon {
            width: units.gu(3)
            height: units.gu(3)
            name: "up"
            color: "#E95420"

            SequentialAnimation on y {
                loops: Animation.Infinite
                running: arrow.visible
                NumberAnimation { from: units.gu(2); to: 0; duration: 900; easing.type: Easing.OutQuad }
                NumberAnimation { to: units.gu(2); duration: 400 }
            }
        }
    }

    Rectangle {
        id: card
        width: Math.max(0, Math.min(tutorial.width - units.gu(4), units.gu(46)))
        x: (tutorial.width - width) / 2
        y: tutorial.cardY
        height: cardColumn.implicitHeight + units.gu(3)
        radius: units.gu(1)
        color: Theme.palette.normal.overlay
        border.width: units.gu(0.2)
        border.color: "#E95420"

        Column {
            id: cardColumn
            x: units.gu(1.5)
            y: units.gu(1.5)
            width: Math.max(0, parent.width - units.gu(3))
            spacing: units.gu(1)

            Label {
                width: parent.width
                text: tutorial.currentStep ? tutorial.currentStep.title : ""
                color: Theme.palette.normal.overlayText
                font.bold: true
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                text: tutorial.currentStep ? tutorial.currentStep.text : ""
                color: Theme.palette.normal.overlayText
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                text: i18n.tr("Step %1 of %2").arg(tutorial.stepIndex + 1).arg(tutorial.steps.length)
                color: Theme.palette.normal.overlaySecondaryText
            }

            RowLayout {
                width: parent.width
                spacing: units.gu(1)

                Button {
                    Layout.fillWidth: true
                    text: i18n.tr("Skip")
                    onClicked: tutorial.finished()
                }

                Button {
                    visible: tutorial.stepIndex > 0
                    Layout.fillWidth: true
                    text: i18n.tr("Previous")
                    onClicked: tutorial.previous()
                }

                Button {
                    Layout.fillWidth: true
                    text: tutorial.lastStep ? i18n.tr("Get started") : i18n.tr("Next")
                    onClicked: tutorial.next()
                }
            }
        }
    }

    // the frame follows what it points at: a scrolled page, a list which is
    // still filling itself, a device turned around
    Timer {
        interval: 150
        repeat: true
        running: tutorial.visible
        onTriggered: tutorial.refresh()
    }
}
