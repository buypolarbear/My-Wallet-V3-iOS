//
//  KYCPersonalDetailsController.swift
//  Blockchain
//
//  Created by Maurice A. on 7/9/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import UIKit

/// Personal details entry screen in KYC flow
final class KYCPersonalDetailsController: UIViewController, KYCOnboardingNavigation {

    // MARK: - Properties

    private let birthdatePicker: UIDatePicker!
    var segueIdentifier: String? = "verifyMobileNumber"

    // MARK: - IBOutlets

    @IBOutlet private var firstNameField: UITextField!
    @IBOutlet private var lastNameField: UITextField!
    @IBOutlet private var birthdateField: UITextField!
    @IBOutlet var primaryButton: PrimaryButton!

    override func viewDidLoad() {
        setUpBirthdatePicker()
        birthdateField.inputView = birthdatePicker
    }

    required init?(coder aDecoder: NSCoder) {
        birthdatePicker = UIDatePicker()
        birthdatePicker.datePickerMode = .date
        birthdatePicker.maximumDate = Date()
        super.init(coder: aDecoder)
    }

    // MARK: - Private Methods

    private func setUpBirthdatePicker() {
        let toolBar = UIToolbar()
        toolBar.barStyle = .default
        toolBar.isTranslucent = true
        toolBar.sizeToFit()

        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(submitBirthdate))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(hideBirthdatePicker))
        toolBar.setItems([cancelButton, spaceButton, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true

        birthdateField.inputAccessoryView = toolBar
    }

    @objc private func submitBirthdate() {
        let dateFormatter1 = DateFormatter()
        dateFormatter1.dateStyle = .medium
        dateFormatter1.timeStyle = .none
        birthdateField.text = dateFormatter1.string(from: birthdatePicker.date)
        birthdateField.resignFirstResponder()
    }

    @objc private func hideBirthdatePicker() {
        birthdateField.resignFirstResponder()
    }

    // MARK: - Actions

    @IBAction func primaryButtonTapped(_ sender: Any) {
        let dateOfBirth = birthdatePicker.date
        let calendar = Calendar(identifier: .gregorian)
        let age = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        guard let year = age.year, year >= 18 else {
            AlertViewPresenter.shared.standardNotify(
                message: "You must be at least 18 years old to have your identity verified",
                title: "A bit too young",
                actions: [
                    UIAlertAction(title: "OK, I understand", style: .default, handler: { _ in
                        // TODO: exit KYC flow and send user back to dashboard
                    })
                ],
                in: self
            )
            return
        }
        performSegue(withIdentifier: segueIdentifier!, sender: self)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {}
}
