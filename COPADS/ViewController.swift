//
//  ViewController.swift
//  COPADS
//
//  Created by Harlan Haskins on 10/9/16.
//  Copyright © 2016 Harlan. All rights reserved.
//

import UIKit
import WebKit

enum DecryptError: Error {
    case incorrectKey
    case couldNotParseCiphertext
    case noCredentials
}

extension Data {

    /// Creates Data from a hexadecimal string.
    /// - seealso: `Data.hexString`
    init?(hexString: String) {
        var bytes = [UInt8]()
        let chars = Array(hexString.characters)
        for i in stride(from: 0, to: chars.count - 1, by: 2) {
            let byteChars = chars[i...i+1]
            guard let byte = UInt8(String(byteChars), radix: 16) else {
                print("unknown byte \(chars)")
                return nil
            }
            bytes.append(byte)
        }
        self.init(bytes: bytes)
    }

    /// Returns a hexademical string representing the bytes of this data.
    /// - seealso: `Data.init(hexString:)`
    var hexString: String {
        var result = ""
        for byte in self {
            result.append(String(byte, radix: 16))
        }
        return result
    }

    /// Uses RC4 to decrypt data in-place with a provided key
    mutating func decrypt(key: Data) throws {
        // Get nonce (first 8 bytes of ciphertext), append key.
        let nonce = self[0..<8] + key
        
        // Initialize RC4 keystream generator.
        var S = Array<UInt8>(0...255)
        var j = 0
        for i in 0...255 {
            j = (j + Int(S[i]) + Int(nonce[i & 15])) & 255
            if i != j {
                swap(&S[j], &S[i])
            }
        }
        
        var x = 0
        var y = 0
        // Decrypt ciphertext, omitting nonce.
        for i in 8..<self.count {
            x = (x + 1) & 255
            y = (y + Int(S[x])) & 255
            if x != y {
                swap(&S[x], &S[y])
            }
            let index = (Int(S[x]) + Int(S[y])) & 255
            self[i] ^= S[index]
        }
        
        // Check key verification string.
        for i in stride(from: 8, to: 24, by: 2) where self[i] != self[i+1] {
            throw DecryptError.incorrectKey
        }
        
        self.removeFirst(24)
    }

    /// Decrypts the receiver with the provided key
    func decrypted(key: Data) throws -> Data {
        var cipherData = self
        try cipherData.decrypt(key: key)
        return cipherData
    }
}

class ViewController: UIViewController {
    @IBOutlet var webView: UIWebView!
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    var activityButton: UIBarButtonItem!

    @IBOutlet var fetchButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.startAnimating()
        activityButton = UIBarButtonItem(customView: activityIndicator)
        fetch(1)
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /// Default CSS Styles for making the raw grades more pleasant.
    var style: String {
        return [
            "<style>",
            "html {",
            "  font-family: -apple-system, sans-serif;",
            "  font-size: 8pt",
            "}",
            "hr {",
            "    border: 0;",
            "    border-top: 1px solid #8c8c8c;",
            "    border-bottom: 1px solid #fff;",
            "}",
            "</style>"
        ].joined(separator: "\n")
    }

    /// Regex to match 1 or more -'s, plus a newline.
    let dashSepRegex = try! NSRegularExpression(pattern: "-+\n", options: .anchorsMatchLines)

    /// Fetches grades from the COPADS server and reformats them in HTML.
    @IBAction func fetch(_ sender: Any) {
        navigationItem.rightBarButtonItem = activityButton
        DispatchQueue.global().async {
            self.loadGrades { text in
                DispatchQueue.main.async {
                    self.navigationItem.rightBarButtonItem = self.fetchButton
                    var text = text
                    text = self.dashSepRegex.stringByReplacingMatches(in: text, options: [],
                                                                      range: NSRange(location: 0,
                                                                                     length: text.utf16.count),
                                                                      withTemplate: "<hr>")
                    text = text.replacingOccurrences(of: "\n", with: "\n<br />")
                    text = "<html>\(self.style)\n<body>\(text)</body></html>"
                    self.webView.loadHTMLString(text,
                                                baseURL: nil)
                }
            }
        }
    }

    /// Loads grades asynchronously and calls the completion when it's successfully
    /// decrypted them.
    func loadGrades(_ completion: (String) -> Void) {
        do {
            guard
                let user = UserDefaults.standard.string(forKey: "user"),
                let course = UserDefaults.standard.string(forKey: "course"),
                let key = UserDefaults.standard.string(forKey: "key") else {
                throw DecryptError.noCredentials
            }
            let gradeURL = URL(string: "https://www.cs.rit.edu/~ark/\(course)/grades/grades.php?user=\(user)")!
            let contents = try String(contentsOf: gradeURL)
            let nsContents = contents as NSString
            let regex = try NSRegularExpression(pattern: "NAME=\"Ciphertext\" VALUE=\"(\\w+)\"")
            let range = NSRange(location: 0, length: nsContents.length)
            guard let match = regex.firstMatch(in: contents, range: range) else {
                throw DecryptError.couldNotParseCiphertext
            }
            let ciphertext = nsContents.substring(with: match.rangeAt(1))
            
            let keyData = Data(hexString: key)!
            var cipherData = Data(hexString: ciphertext)!
            try cipherData.decrypt(key: keyData)
            let string = String(data: cipherData, encoding: .ascii)!
            completion(string)
        } catch {
            completion("could not decrypt: \(error)")
        }
    }

}

