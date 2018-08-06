//
//  KYCCountrySelectionController.swift
//  Blockchain
//
//  Created by Maurice A. on 7/9/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import UIKit

/// Country selection screen in KYC flow
final class KYCCountrySelectionController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: Private Properties

    fileprivate let searchController = UISearchController(searchResultsController: nil)

    // MARK: Private IBOutlets

    @IBOutlet fileprivate var headline: UILabel!
    @IBOutlet fileprivate var subheadline: UILabel!
    @IBOutlet fileprivate var progressView: UIProgressView!
    @IBOutlet fileprivate var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.showsCancelButton = false

        // TODO: Localize
        searchController.searchBar.placeholder = "Search"
        tableView.tableHeaderView = searchController.searchBar

        dataProvider = CountryDataProvider()
        dataProvider?.fetchListOfCountries()

    }

    // MARK: - Properties

    var dataProvider: CountryDataProvider?

    // MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let countries = dataProvider?.countries else {
            return 0
        }
        return countries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let countryCell = tableView.dequeueReusableCell(withIdentifier: "CountryCell"),
            let countries = dataProvider?.countries else {
                return UITableViewCell()
        }
        countryCell.textLabel?.text = countries[indexPath.row].name
        return countryCell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "promptForPersonalDetails", sender: self)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // TODO: implement method body
    }
}
