//
//  KYCAddressController.swift
//  Blockchain
//
//  Created by Maurice A. on 7/9/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import UIKit

class KYCAddressController: KYCBaseViewController, ValidationFormView {

    // MARK: - Private IBOutlets

    @IBOutlet fileprivate var progressView: UIProgressView!
    @IBOutlet fileprivate var searchBar: UISearchBar!
    @IBOutlet fileprivate var tableView: UITableView!
    @IBOutlet fileprivate var activityIndicator: UIActivityIndicatorView!

    // MARK: Private IBOutlets (ValidationTextField)
    @IBOutlet fileprivate var addressTextField: ValidationTextField!
    @IBOutlet fileprivate var apartmentTextField: ValidationTextField!
    @IBOutlet fileprivate var cityTextField: ValidationTextField!
    @IBOutlet fileprivate var stateTextField: ValidationTextField!
    @IBOutlet fileprivate var postalCodeTextField: ValidationTextField!
    @IBOutlet fileprivate var countryTextField: ValidationTextField!
    @IBOutlet fileprivate var primaryButtonContainer: PrimaryButtonContainer!

    // MARK: - Public IBOutlets

    @IBOutlet var scrollView: UIScrollView!

    // MARK: Factory

    override class func make(with coordinator: KYCCoordinator) -> KYCAddressController {
        let storyboard = UIStoryboard(name: "KYCAddress", bundle: nil)
        let controller = storyboard.instantiateInitialViewController() as! KYCAddressController
        controller.coordinator = coordinator
        controller.pageType = .address
        return controller
    }

    // MARK: - KYCOnboardingNavigation

    weak var searchDelegate: SearchControllerDelegate?

    /// `validationFields` are all the fields listed below in a collection.
    /// This is just for convenience purposes when iterating over the fields
    /// and checking validation etc.
    var validationFields: [ValidationTextField] {
        get {
            return [addressTextField,
                    apartmentTextField,
                    cityTextField,
                    stateTextField,
                    postalCodeTextField,
                    countryTextField
            ]
        }
    }

    var keyboard: KeyboardPayload? = nil

    // MARK: Private Properties

    fileprivate var locationCoordinator: LocationSuggestionCoordinator!
    fileprivate var dataProvider: LocationDataProvider!

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        locationCoordinator = LocationSuggestionCoordinator(self, interface: self)
        dataProvider = LocationDataProvider(with: tableView)
        searchBar.delegate = self
        tableView.delegate = self

        searchBar.barTintColor = .clear

        // TODO: Localize
        searchBar.placeholder = "Your Home Address"
        progressView.tintColor = .green

        validationFieldsSetup()
        setupNotifications()

        primaryButtonContainer.actionBlock = { [weak self] in
            guard let this = self else { return }
            this.primaryButtonTapped()
        }

        searchDelegate?.onStart()
    }

    // MARK: Private Functions

    fileprivate func validationFieldsSetup() {

        /// Given that this is a form, we want all the fields
        /// except for the last one to prompt the user to
        /// continue to the next field.
        /// We also set the contentType that the field is expecting.
        addressTextField.returnKeyType = .next
        addressTextField.contentType = .streetAddressLine1

        apartmentTextField.returnKeyType = .next
        apartmentTextField.contentType = .streetAddressLine2

        cityTextField.returnKeyType = .next
        cityTextField.contentType = .addressCity

        stateTextField.returnKeyType = .next
        stateTextField.contentType = .addressState

        postalCodeTextField.returnKeyType = .next
        postalCodeTextField.contentType = .postalCode

        countryTextField.returnKeyType = .done
        countryTextField.contentType = .countryName

        validationFields.enumerated().forEach { (index, field) in
            field.returnTappedBlock = { [weak self] in
                guard let this = self else { return }
                guard this.validationFields.count > index + 1 else {
                    field.resignFocus()
                    return
                }
                let next = this.validationFields[index + 1]
                next.becomeFocused()
            }
        }

        handleKeyboardOffset()
    }

    fileprivate func setupNotifications() {
        NotificationCenter.when(.UIKeyboardWillHide) { [weak self] _ in
            self?.scrollView.contentInset = .zero
            self?.scrollView.setContentOffset(.zero, animated: true)
        }
        NotificationCenter.when(.UIKeyboardWillShow) { [weak self] notification in
            let keyboard = KeyboardPayload(notification: notification)
            self?.keyboard = keyboard
        }
    }

    fileprivate func primaryButtonTapped() {
        guard checkFieldsValidity() else { return }
        validationFields.forEach({$0.resignFocus()})
        
        let address = UserAddress(
            lineOne: addressTextField.text ?? "",
            lineTwo: apartmentTextField.text ?? "",
            postalCode: postalCodeTextField.text ?? "",
            city: cityTextField.text ?? "",
            state: stateTextField.text ?? "",
            country: countryTextField.text ?? ""
        )
        searchDelegate?.onSubmission(address, completion: { [weak self] in
            guard let this = self else { return }
            this.coordinator.handle(event: .nextPageFromPageType(this.pageType))
        })
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // TODO: implement method body
    }
}

extension KYCAddressController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selection = dataProvider.locationResult.suggestions[indexPath.row]
        locationCoordinator.onSelection(selection)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
    }
}

extension KYCAddressController: LocationSuggestionInterface {
    func primaryButtonActivityIndicator(_ visibility: Visibility) {
        primaryButtonContainer.isLoading = visibility == .visible
    }

    func primaryButtonEnabled(_ enabled: Bool) {
        primaryButtonContainer.isEnabled = enabled
    }

    func addressEntryView(_ visibility: Visibility) {
        scrollView.alpha = visibility.defaultAlpha
    }

    func populateAddressEntryView(_ address: PostalAddress) {
        addressTextField.text = "\(address.streetNumber ?? "") \(address.street ?? "")"
        cityTextField.text = address.city
        stateTextField.text = address.state
        postalCodeTextField.text = address.postalCode
        countryTextField.text = address.country
    }

    func updateActivityIndicator(_ visibility: Visibility) {
        visibility == .hidden ? activityIndicator.stopAnimating() : activityIndicator.startAnimating()
    }

    func suggestionsList(_ visibility: Visibility) {
        tableView.alpha = visibility.defaultAlpha
    }

    func searchFieldActive(_ isFirstResponder: Bool) {
        switch isFirstResponder {
        case true:
            searchBar.becomeFirstResponder()
        case false:
            searchBar.resignFirstResponder()
        }
    }

    func searchFieldText(_ value: String?) {
        searchBar.text = value
    }
}

extension KYCAddressController: LocationSuggestionCoordinatorDelegate {
    func coordinator(_ locationCoordinator: LocationSuggestionCoordinator, generated address: PostalAddress) {
        // TODO: May not be needed depending on how we pass along the `PostalAddress`
    }

    func coordinator(_ locationCoordinator: LocationSuggestionCoordinator, updated model: LocationSearchResult) {
        dataProvider.locationResult = model
    }
}

extension KYCAddressController: UISearchBarDelegate {

    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        searchBar.setShowsCancelButton(true, animated: true)
        return true
    }

    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        searchBar.setShowsCancelButton(false, animated: true)
        return true
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchDelegate?.onStart()
        scrollView.setContentOffset(.zero, animated: true)
    }

    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if let value = searchBar.text as NSString? {
            let current = value.replacingCharacters(in: range, with: text)
            searchDelegate?.onSearchRequest(current)
        }
        return true
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if let value = searchBar.text {
            searchDelegate?.onSearchRequest(value)
        }
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchDelegate?.onSearchViewCancel()
    }
}

extension KYCAddressController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        validationFields.forEach({$0.resignFocus()})
    }
}
