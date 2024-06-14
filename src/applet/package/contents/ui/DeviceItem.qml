/*
    SPDX-FileCopyrightText: 2013-2014 Jan Grulich <jgrulich@redhat.com>
    SPDX-FileCopyrightText: 2014-2015 David Rosca <nowrep@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.bluezqt as BluezQt
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.bluetooth as PlasmaBt

PlasmaExtras.ExpandableListItem {
    id: expandableListItem

    property bool connecting: false
    property bool connectionFailed: false
    property var currentDeviceDetails: []

    icon: model.Icon
    title: model.DeviceFullName
    subtitle: infoText()
    isBusy: connecting
    isDefault: model.Connected
    defaultActionButtonAction: QQC2.Action {
        icon.name: model.Connected ? "network-disconnect-symbolic" : "network-connect-symbolic"
        text: model.Connected ? i18n("Disconnect") : i18n("Connect")
        onTriggered: source => connectToDevice()
    }

    contextualActions: [
        QQC2.Action {
            id: browseFilesButton
            enabled: Uuids.indexOf(BluezQt.Services.ObexFileTransfer) !== -1
            icon.name: "folder-symbolic"
            text: i18n("Browse Files")

            onTriggered: source => {
                const url = "obexftp://%1/".arg(Address.replace(/:/g, "-"));
                Qt.openUrlExternally(url);
            }
        },
        QQC2.Action {
            id: sendFileButton
            enabled: Uuids.indexOf(BluezQt.Services.ObexObjectPush) !== -1
            icon.name: "document-share-symbolic"
            text: i18n("Send File")

            onTriggered: source => {
                PlasmaBt.LaunchApp.launchSendFile(Ubi);
            }
        }
    ]

    customExpandedViewContent: Component {
        id: expandedView

        ColumnLayout {
            spacing: 0

            // Media Player
            MediaPlayerItem {
                id: mediaPlayerItem
                mediaPlayer: model.MediaPlayer
                Layout.leftMargin: Kirigami.Units.gridUnit + Kirigami.Units.smallSpacing * 3
                Layout.fillWidth: true
                visible: mediaPlayer !== null
            }

            Item {
                Layout.preferredHeight: Kirigami.Units.smallSpacing
                visible: mediaPlayerItem.visible
            }

            KSvg.SvgItem {
                id: mediaPlayerSeparator
                Layout.fillWidth: true
                imagePath: "widgets/line"
                elementId: "horizontal-line"
                visible: mediaPlayerItem.visible
                    || (!mediaPlayerItem.visible && !(browseFilesButton.enabled || sendFileButton.enabled))
            }

            Item {
                Layout.preferredHeight: Kirigami.Units.smallSpacing
                visible: mediaPlayerSeparator.visible
            }

            KQuickControlsAddons.Clipboard {
                id: clipboard
            }

            PlasmaExtras.Menu {
                id: contextMenu
                property string text

                function show(item, text, x, y) {
                    contextMenu.text = text
                    visualParent = item
                    open(x, y)
                }

                PlasmaExtras.MenuItem {
                    text: i18n("Copy")
                    icon: "edit-copy-symbolic"
                    enabled: contextMenu.text !== ""
                    onClicked: clipboard.content = contextMenu.text
                }
            }

            // Details
            MouseArea {
                Layout.fillWidth: true
                Layout.preferredHeight: detailsGrid.implicitHeight

                acceptedButtons: Qt.RightButton
                activeFocusOnTab: repeater.count > 0

                Accessible.description: {
                    let description = [];
                    for (let i = 0; i < currentDeviceDetails.length; i += 2) {
                        description.push(currentDeviceDetails[i]);
                        description.push(": ");
                        description.push(currentDeviceDetails[i + 1]);
                        description.push("; ");
                    }
                    return description.join('');
                }

                onPressed: mouse => {
                    const item = detailsGrid.childAt(mouse.x, mouse.y);
                    if (!item || !item.isContent) {
                        return; // only let users copy the value on the right
                    }

                    contextMenu.show(this, item.text, mouse.x, mouse.y);
                }

                Loader {
                    anchors.fill: parent
                    active: parent.activeFocus
                    asynchronous: true
                    z: -1

                    sourceComponent: PlasmaExtras.Highlight {
                        hovered: true
                    }
                }

                GridLayout {
                    id: detailsGrid
                    width: parent.width
                    columns: 2
                    rowSpacing: Kirigami.Units.smallSpacing / 4

                    Repeater {
                        id: repeater

                        model: currentDeviceDetails.length

                        PlasmaComponents3.Label {
                            id: detailLabel

                            Layout.fillWidth: true

                            readonly property bool isContent: index % 2

                            horizontalAlignment: isContent ? Text.AlignLeft : Text.AlignRight
                            elide: isContent ? Text.ElideRight : Text.ElideNone
                            font: Kirigami.Theme.smallFont
                            opacity: isContent ? 1 : 0.6
                            text: isContent ? currentDeviceDetails[index] : `${currentDeviceDetails[index]}:`
                            textFormat: isContent ? Text.PlainText : Text.StyledText
                        }
                    }
                }
            }

            Component.onCompleted: createContent()
        }
    }

    // Hide device details when the device for this delegate changes
    // This happens eg. when device connects/disconnects
    property QtObject __dev
    readonly property QtObject dev : Device
    onDevChanged: {
        if (__dev === dev) {
            return;
        }
        __dev = dev;

        if (expandedView.status === Component.Ready) {
            expandableListItem.collapse();
            expandableListItem.ListView.view.currentIndex = -1;
        }
    }

    function boolToString(v): string {
        return v ? i18n("Yes") : i18n("No");
    }

    function adapterName(a): string {
        const hci = devicesModel.adapterHciString(a.ubi);
        return (hci !== "")
            ? i18nc("@label %1 is human-readable adapter name, %2 is HCI", "%1 (%2)", a.name, hci)
            : a.name;
    }

    function createContent() {
        const details = [];

        if (Name !== RemoteName) {
            details.push(i18n("Remote Name"));
            details.push(RemoteName);
        }

        details.push(i18n("Address"));
        details.push(Address);

        details.push(i18n("Paired"));
        details.push(boolToString(Paired));

        details.push(i18n("Trusted"));
        details.push(boolToString(Trusted));

        details.push(i18n("Adapter"));
        details.push(adapterName(Adapter));

        currentDeviceDetails = details;
    }

    function infoText(): string {
        if (connecting) {
            return Connected ? i18n("Disconnecting") : i18n("Connecting");
        }

        const labels = [];

        if (Connected) {
            labels.push(i18n("Connected"));
        } else if (connectionFailed) {
            labels.push(i18n("Connection failed"));
        }

        switch (Type) {
        case BluezQt.Device.Headset:
        case BluezQt.Device.Headphones:
        case BluezQt.Device.OtherAudio:
            labels.push(i18n("Audio device"));
            break;

        case BluezQt.Device.Keyboard:
        case BluezQt.Device.Mouse:
        case BluezQt.Device.Joypad:
        case BluezQt.Device.Tablet:
            labels.push(i18n("Input device"));
            break;

        case BluezQt.Device.Phone:
            labels.push(i18n("Phone"));
            break;

        default:
            const profiles = [];

            if (Uuids.indexOf(BluezQt.Services.ObexFileTransfer) !== -1) {
                profiles.push(i18n("File transfer"));
            }
            if (Uuids.indexOf(BluezQt.Services.ObexObjectPush) !== -1) {
                profiles.push(i18n("Send file"));
            }
            if (Uuids.indexOf(BluezQt.Services.HumanInterfaceDevice) !== -1) {
                profiles.push(i18n("Input"));
            }
            if (Uuids.indexOf(BluezQt.Services.AdvancedAudioDistribution) !== -1) {
                profiles.push(i18n("Audio"));
            }
            if (Uuids.indexOf(BluezQt.Services.Nap) !== -1) {
                profiles.push(i18n("Network"));
            }

            if (!profiles.length) {
                profiles.push(i18n("Other device"));
            }

            labels.push(profiles.join(", "));
        }

        if (Battery) {
            labels.push(i18n("%1% Battery", Battery.percentage));
        }

        return labels.join(" · ");
    }

    function errorText(/*PendingCall*/ call): string {
        switch (call.error) {
        case BluezQt.PendingCall.Failed:
            return (call.errorText === "Host is down")
                ? i18nc("Notification when the connection failed due to Failed:HostIsDown",
                        "The device is unreachable")
                : i18nc("Notification when the connection failed due to Failed",
                        "Connection to the device failed");

        case BluezQt.PendingCall.NotReady:
            return i18nc("Notification when the connection failed due to NotReady",
                         "The device is not ready");

        default:
            return "";
        }
    }

    function connectToDevice() {
        if (connecting) {
            return;
        }

        connecting = true;
        runningActions++;

        // Disconnect device
        if (Connected) {
            Device.disconnectFromDevice().finished.connect(call => {
                connecting = false;
                runningActions--;
            });
            return;
        }

        // Connect device
        const /*PendingCall*/call = Device.connectToDevice();
        call.userData = Device;
        connectionFailed = false;

        call.finished.connect(call => {
            connecting = false;
            runningActions--;

            if (call.error) {
                connectionFailed = true;
                const device = call.userData;
                const title = i18nc("@label %1 is human-readable device name, %2 is low-level device address", "%1 (%2)", device.name, device.address);
                const text = errorText(call);

                PlasmaBt.Notify.connectionFailed(title, text);
            }
        });
    }
}
