//
//  ShareOptionsView.swift
//  FileProviderUIExt
//
//  Created by Claudio Cambra on 28/2/24.
//

import AppKit
import Combine
import NextcloudKit
import OSLog

// TODO: Handle shareWith!
// TODO: Handle visibility of textfields on relevant checkbox toggle
class ShareOptionsView: NSView {
    @IBOutlet private weak var optionsTitleTextField: NSTextField!
    @IBOutlet private weak var shareRecipientTextField: NSTextField!  // Hide if public link share
    @IBOutlet private weak var labelTextField: NSTextField!
    @IBOutlet private weak var uploadEditPermissionCheckbox: NSButton!
    @IBOutlet private weak var hideDownloadCheckbox: NSButton!
    @IBOutlet private weak var passwordProtectCheckbox: NSButton!
    @IBOutlet private weak var passwordSecureField: NSSecureTextField!
    @IBOutlet private weak var expirationDateCheckbox: NSButton!
    @IBOutlet private weak var expirationDatePicker: NSDatePicker!
    @IBOutlet private weak var noteForRecipientCheckbox: NSButton!
    @IBOutlet private weak var noteTextField: NSTextField!
    @IBOutlet private weak var saveButton: NSButton!
    @IBOutlet private weak var deleteButton: NSButton!
    @IBOutlet private weak var shareTypePicker: NSPopUpButton!
    @IBOutlet private weak var publicLinkShareMenuItem: NSMenuItem!
    @IBOutlet private weak var userShareMenuItem: NSMenuItem!
    @IBOutlet private weak var groupShareMenuItem: NSMenuItem!
    @IBOutlet private weak var emailShareMenuItem: NSMenuItem!
    @IBOutlet private weak var federatedCloudShareMenuItem: NSMenuItem!
    @IBOutlet private weak var circleShare: NSMenuItem!
    @IBOutlet private weak var talkConversationShare: NSMenuItem!

    var dataSource: ShareTableViewDataSource?
    var controller: ShareController? {
        didSet {
            guard controller != nil else { return }
            optionsTitleTextField.stringValue = "Share options"
            deleteButton.title = "Delete"
            deleteButton.image = NSImage(
                systemSymbolName: "trash", accessibilityDescription: "Delete trash icon"
            )
            deleteButton.bezelColor = NSColor.systemRed
            cancellable?.cancel()
            createMode = false
            update()
            cancellable = controller.publisher.sink { _ in self.update() }
        }
    }
    var createMode = false {
        didSet {
            Logger.shareOptionsView.info("Create mode set: \(self.createMode)")
            shareTypePicker.isHidden = !createMode
            shareRecipientTextField.isHidden = !createMode
            labelTextField.isHidden = createMode  // Cannot set label on create API call
            guard createMode else { return }
            optionsTitleTextField.stringValue = "Create new share"
            deleteButton.title = "Cancel"
            deleteButton.image = NSImage(
                systemSymbolName: "xmark.bin", accessibilityDescription: "Cancel create icon"
            )
            deleteButton.bezelColor = NSColor.controlColor
            cancellable?.cancel()
            cancellable = nil
            controller = nil
            reset()
            setupCreateForm()
        }
    }
    private var cancellable: AnyCancellable?

    private func update() {
        guard let share = controller?.share else {
            reset()
            setAllFields(enabled: false)
            saveButton.isEnabled = false
            deleteButton.isEnabled = false
            return
        }

        deleteButton.isEnabled = share.canDelete
        saveButton.isEnabled = share.canEdit

        if share.canEdit {
            setAllFields(enabled: true)
            labelTextField.stringValue = share.label
            uploadEditPermissionCheckbox.state = share.shareesCanEdit ? .on : .off
            hideDownloadCheckbox.state = share.hideDownload ? .on : .off
            passwordProtectCheckbox.state = share.password.isEmpty ? .off : .on
            passwordSecureField.isHidden = passwordProtectCheckbox.state == .off
            expirationDateCheckbox.state = share.expirationDate == nil ? .off : .on
            expirationDatePicker.isHidden = expirationDateCheckbox.state == .off
            noteForRecipientCheckbox.state = share.note.isEmpty ? .off : .on
            noteTextField.isHidden = noteForRecipientCheckbox.state == .off
        } else {
            setAllFields(enabled: false)
            reset()
        }
    }

    private func reset() {
        shareRecipientTextField.stringValue = ""
        labelTextField.stringValue = ""
        uploadEditPermissionCheckbox.state = .off
        hideDownloadCheckbox.state = .off
        passwordProtectCheckbox.state = .off
        passwordSecureField.isHidden = true
        passwordSecureField.stringValue = ""
        expirationDateCheckbox.state = .off
        expirationDatePicker.isHidden = true
        expirationDatePicker.dateValue = NSDate.now
        expirationDatePicker.minDate = NSDate.now
        expirationDatePicker.maxDate = nil
        noteForRecipientCheckbox.state = .off
        noteTextField.isHidden = true
        noteTextField.stringValue = ""
    }

    private func setupCreateForm() {
        guard createMode else { return }

        setAllFields(enabled: true)

        let type = pickedShareType()
        shareRecipientTextField.isHidden = type != .publicLink

        if let caps = dataSource?.shareCapabilities {
            uploadEditPermissionCheckbox.state =
                caps.defaultPermissions & NKShare.PermissionValues.updateShare.rawValue != 0
                ? .on : .off

            switch type {
            case .publicLink:
                passwordProtectCheckbox.isHidden = false
                passwordProtectCheckbox.state = caps.publicLink.enforcePassword ? .on : .off
                passwordProtectCheckbox.isEnabled = !caps.publicLink.enforceExpireDate
                expirationDateCheckbox.state = caps.publicLink.enforceExpireDate ? .on : .off
                expirationDateCheckbox.isEnabled = !caps.publicLink.enforceExpireDate
                expirationDatePicker.dateValue = Date(
                    timeIntervalSinceNow: 
                        TimeInterval(caps.publicLink.expireDateDays * 24 * 60 * 60)
                )
                if caps.publicLink.enforceExpireDate {
                    expirationDatePicker.maxDate = expirationDatePicker.dateValue
                }
            case .email:
                passwordProtectCheckbox.isHidden = !caps.email.passwordEnabled
                passwordProtectCheckbox.state = caps.email.passwordEnforced ? .on : .off
            default:
                break
            }
        }

        passwordSecureField.isHidden = passwordProtectCheckbox.state == .off
        expirationDatePicker.isHidden = expirationDateCheckbox.state == .off
    }

    func setAllFields(enabled: Bool) {
        shareTypePicker.isEnabled = enabled
        shareRecipientTextField.isEnabled = enabled
        labelTextField.isEnabled = enabled
        uploadEditPermissionCheckbox.isEnabled = enabled
        hideDownloadCheckbox.isEnabled = enabled
        passwordProtectCheckbox.isEnabled = enabled
        passwordSecureField.isEnabled = enabled
        expirationDateCheckbox.isEnabled = enabled
        expirationDatePicker.isEnabled = enabled
        noteForRecipientCheckbox.isEnabled = enabled
        noteTextField.isEnabled = enabled
        saveButton.isEnabled = enabled
        deleteButton.isEnabled = enabled
    }

    private func pickedShareType() -> NKShare.ShareType {
        let selectedShareTypeItem = shareTypePicker.selectedItem
        var selectedShareType = NKShare.ShareType.publicLink
        if selectedShareTypeItem == publicLinkShareMenuItem {
            selectedShareType = .publicLink
        } else if selectedShareTypeItem == userShareMenuItem {
            selectedShareType = .user
        } else if selectedShareTypeItem == groupShareMenuItem {
            selectedShareType = .group
        } else if selectedShareTypeItem == emailShareMenuItem {
            selectedShareType = .email
        } else if selectedShareTypeItem == federatedCloudShareMenuItem {
            selectedShareType = .federatedCloud
        } else if selectedShareTypeItem == circleShare {
            selectedShareType = .circle
        } else if selectedShareTypeItem == talkConversationShare {
            selectedShareType = .talkConversation
        }
        return selectedShareType
    }

    @IBAction func passwordCheckboxAction(_ sender: Any) {
        passwordSecureField.isHidden = passwordProtectCheckbox.state == .off
    }

    @IBAction func expirationDateCheckboxAction(_ sender: Any) {
        expirationDatePicker.isHidden = expirationDateCheckbox.state == .off
    }

    @IBAction func noteForRecipientCheckboxAction(_ sender: Any) {
        noteTextField.isHidden = noteForRecipientCheckbox.state == .off
    }

    @IBAction func save(_ sender: Any) {
        Task { @MainActor in
            let password = passwordProtectCheckbox.state == .on
                ? passwordSecureField.stringValue
                : ""
            let expireDate = expirationDateCheckbox.state == .on
                ? NKShare.formattedDateString(date: expirationDatePicker.dateValue)
                : ""
            let note = noteForRecipientCheckbox.state == .on
                ? noteTextField.stringValue
                : ""
            let label = labelTextField.stringValue
            let hideDownload = hideDownloadCheckbox.state == .on
            let uploadAndEdit = uploadEditPermissionCheckbox.state == .on

            guard !createMode else {
                Logger.shareOptionsView.info("Creating new share!")

                guard let dataSource = dataSource,
                      let kit = dataSource.kit,
                      let itemServerRelativePath = dataSource.itemServerRelativePath
                else {
                    Logger.shareOptionsView.error("Cannot create new share due to missing data.")
                    Logger.shareOptionsView.error("dataSource: \(self.dataSource)")
                    Logger.shareOptionsView.error("kit: \(self.dataSource?.kit)")
                    Logger.shareOptionsView.error(
                        "path: \(self.dataSource?.itemServerRelativePath ?? "")"
                    )
                    return
                }

                let selectedShareType = pickedShareType()
                let shareWith = shareRecipientTextField.stringValue

                var permissions = NKShare.PermissionValues.all.rawValue
                permissions = uploadAndEdit
                    ? permissions | NKShare.PermissionValues.updateShare.rawValue
                    : permissions & ~NKShare.PermissionValues.updateShare.rawValue

                setAllFields(enabled: false)
                deleteButton.isEnabled = false
                saveButton.isEnabled = false
                let error = await ShareController.create(
                    kit: kit,
                    shareType: selectedShareType,
                    itemServerRelativePath: itemServerRelativePath,
                    shareWith: shareWith,
                    password: password,
                    expireDate: expireDate,
                    permissions: permissions,
                    note: note,
                    label: label,
                    hideDownload: hideDownload
                )
                if let error = error, error != .success {
                    dataSource.uiDelegate?.showError("Error creating: \(error.errorDescription)")
                    setAllFields(enabled: true)
                } else {
                    dataSource.uiDelegate?.hideOptions()
                    await dataSource.reload()
                }
                return
            }

            Logger.shareOptionsView.info("Editing existing share!")

            guard let controller = controller else {
                Logger.shareOptionsView.error("No valid share controller, cannot edit share.")
                return
            }
            let share = controller.share
            let permissions = uploadAndEdit
                ? share.permissions | NKShare.PermissionValues.updateShare.rawValue
                : share.permissions & ~NKShare.PermissionValues.updateShare.rawValue

            setAllFields(enabled: false)
            deleteButton.isEnabled = false
            saveButton.isEnabled = false
            let error = await controller.save(
                password: password,
                expireDate: expireDate,
                permissions: permissions,
                note: note,
                label: label,
                hideDownload: hideDownload
            )
            if let error = error, error != .success {
                dataSource?.uiDelegate?.showError("Error updating share: \(error.errorDescription)")
                setAllFields(enabled: true)
            } else {
                dataSource?.uiDelegate?.hideOptions()
                await dataSource?.reload()
            }
        }
    }

    @IBAction func delete(_ sender: Any) {
        Task { @MainActor in
            guard !createMode else {
                dataSource?.uiDelegate?.hideOptions()
                reset()
                return
            }

            setAllFields(enabled: false)
            deleteButton.isEnabled = false
            saveButton.isEnabled = false
            let error = await controller?.delete()
            if let error = error, error != .success {
                dataSource?.uiDelegate?.showError("Error deleting share: \(error.errorDescription)")
            }
            await dataSource?.reload()
        }
    }
}