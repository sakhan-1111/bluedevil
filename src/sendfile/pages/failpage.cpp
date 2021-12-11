/*
 * This file is part of the KDE project
 *
 * SPDX-FileCopyrightText: 2015 David Rosca <nowrep@gmail.com>
 *
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

#include "failpage.h"
#include "../sendfilewizard.h"
#include "bluedevil_sendfile.h"

#include <QPushButton>

#include <KLocalizedString>
#include <KPixmapSequenceOverlayPainter>
#include <KStandardGuiItem>

#include <BluezQt/Device>

FailPage::FailPage(SendFileWizard *parent)
    : QWizardPage(parent)
    , m_wizard(parent)
{
    setupUi(this);

    failIcon->setPixmap(QIcon::fromTheme(QStringLiteral("task-reject")).pixmap(48));
}

void FailPage::initializePage()
{
    qCDebug(BLUEDEVIL_SENDFILE_LOG) << "Initialize Fail Page";

    const QList<QWizard::WizardButton> list{QWizard::Stretch, QWizard::CancelButton};

    m_wizard->setButtonLayout(list);

    BluezQt::DevicePtr device = m_wizard->device();

    if (device->name().isEmpty()) {
        failLbl->setText(i18nc("This string is shown when the wizard fail", "The connection to the device has failed"));
    } else {
        failLbl->setText(i18n("The connection to %1 has failed", device->name()));
    }
}
