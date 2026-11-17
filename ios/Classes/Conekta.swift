//
//  Conekta.swift
//  ConektaCardToken-Swift
//
//  Created by Ricardo Michel Reyes Martínez on 7/21/16.
//  Copyright © 2016 Conekta. All rights reserved.
//
import Foundation
import UIKit
import WebKit

class Conekta: NSObject, WKNavigationDelegate
{
    var baseURI = ""
    var publicKey = ""
    var viewController: UIViewController?
    private var deviceCollectionWebView: WKWebView?
    private var deviceCollectionTimer: Timer?

    override init()
    {
        self.baseURI = "https://api.conekta.io"
    }

    func deviceFingerprint() -> String?
    {
        let uuid = UIDevice.current.identifierForVendor?.uuidString
        return uuid?.replacingOccurrences(of: "-", with: "")
    }

    func collectDevice()
    {
        guard let fingerprint = deviceFingerprint(),
              let vc = viewController,
              deviceCollectionWebView == nil else {
            return
        }

        // Conekta's JavaScript only collects a device fingerprint; it must not
        // become a full-screen layer over the Flutter view.
        let html = "<html><head></head><body><script type=\"text/javascript\" src=\"https://conektaapi.s3.amazonaws.com/v0.5.0/js/conekta.js\" data-conekta-public-key=\"\(publicKey)\" data-conekta-session-id=\"\(fingerprint)\"></script></body></html>"
        let webView = WKWebView(frame: CGRect(x: -1, y: -1, width: 1, height: 1))
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.isUserInteractionEnabled = false

        deviceCollectionWebView = webView
        vc.view.addSubview(webView)
        webView.loadHTMLString(html, baseURL: nil)

        // Do not retain this auxiliary WebView indefinitely if its remote
        // JavaScript never finishes loading.
        scheduleDeviceCollectionCleanup(after: 10)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === deviceCollectionWebView else {
            return
        }

        // Allow the loaded script a short window to send its fingerprint.
        scheduleDeviceCollectionCleanup(after: 3)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        removeDeviceCollectionWebView()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        removeDeviceCollectionWebView()
    }

    private func scheduleDeviceCollectionCleanup(after delay: TimeInterval) {
        deviceCollectionTimer?.invalidate()
        deviceCollectionTimer = Timer.scheduledTimer(
            timeInterval: delay,
            target: self,
            selector: #selector(removeDeviceCollectionWebView),
            userInfo: nil,
            repeats: false
        )
    }

    @objc private func removeDeviceCollectionWebView() {
        deviceCollectionTimer?.invalidate()
        deviceCollectionTimer = nil
        deviceCollectionWebView?.navigationDelegate = nil
        deviceCollectionWebView?.removeFromSuperview()
        deviceCollectionWebView = nil
    }

    func card(number: String, name: String, cvc: String, expMonth: String, expYear: String) -> Card
    {
        let card = Card(number: number, name: name, cvc: cvc, expMonth: expMonth, expYear: expYear)
        card.baseURI = self.baseURI
        card.publicKey = self.publicKey
        if let fingerprint = deviceFingerprint()
        {
            card.deviceFingerprint = fingerprint
        }

        return card
    }

    func token(card: Card) -> Token
    {
        let token = Token(card: card)
        token.baseURI = self.baseURI
        token.publicKey = self.publicKey
        if let fingerprint = deviceFingerprint()
        {
            token.deviceFingerprint = fingerprint
        }

        return token
    }
}
