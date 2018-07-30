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

    private let birthdayFieldGesture: UIGestureRecognizer!
    var segueIdentifier: String? = "verifyMobileNumber"

    // MARK: - IBOutlets

    @IBOutlet var firstNameField: UITextField!
    @IBOutlet var lastNameField: UITextField!
    @IBOutlet var birthdayField: UIView!
    @IBOutlet var primaryButton: PrimaryButton!

    // MARK: - Initialization

    required init?(coder aDecoder: NSCoder) {
        birthdayFieldGesture = UIGestureRecognizer(target: birthdayField, action: #selector(showBirthdayPicker))
        super.init(coder: aDecoder)
    }

    // MARK: - Private Methods

    @objc private func showBirthdayPicker() {
        print("showing birthday picker")
    }

    // MARK: - Actions

    @IBAction func primaryButtonTapped(_ sender: Any) {
        performSegue(withIdentifier: segueIdentifier!, sender: self)
//        let verifyAccountController = UIStoryboard.instantiate(
//            child: KYCVerifyAccountController.self,
//            from: KYCOnboardingController.self,
//            in: UIStoryboard(name: "KYCOnboardingScreen", bundle: nil),
//            identifier: "OnboardingScreen"
//        )
//        self.navigationController?.pushViewController(verifyAccountController, animated: true)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {}
}
