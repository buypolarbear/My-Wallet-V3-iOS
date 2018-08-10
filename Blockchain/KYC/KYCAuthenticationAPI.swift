//
//  KYCAuthenticationAPI.swift
//  Blockchain
//
//  Created by kevinwu on 8/10/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

final class KYCAuthenticationAPI {

    private struct Keys {
        static let email = "email"
        static let guid = "guid"
    }

    static func createUser(
        email: String,
        guid: String,
        success: @escaping (Data) -> Void,
        error: @escaping (HTTPRequestError) -> Void
    ) {
        KYCNetworkRequest.init(
            post: KYCNetworkRequest.KYCEndpoints.POST.registerUser,
            parameters: [Keys.email: email, Keys.guid: guid],
            taskSuccess: success,
            taskFailure: error
        )
    }

    static func getApiKey(
        email: String,
        guid: String,
        success: @escaping (Data) -> Void,
        error: @escaping (HTTPRequestError) -> Void
    ) {
        KYCNetworkRequest.init(
            post: KYCNetworkRequest.KYCEndpoints.POST.apiKey,
            parameters: [Keys.email: email, Keys.guid: guid],
            taskSuccess: success,
            taskFailure: error
        )
    }

    static func getSessionToken(
        email: String,
        guid: String,
        success: @escaping (Data) -> Void,
        error: @escaping (HTTPRequestError) -> Void
        ) {
        KYCNetworkRequest.init(
            post: KYCNetworkRequest.KYCEndpoints.POST.sessionToken,
            parameters: [Keys.email: email, Keys.guid: guid],
            taskSuccess: success,
            taskFailure: error
        )
    }
}

