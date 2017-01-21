//
//  CredentialsViewController.swift
//  COPADS
//
//  Created by Harlan Haskins on 10/9/16.
//  Copyright © 2016 Harlan. All rights reserved.
//

import UIKit

class CredentialsViewController: UIViewController {
    @IBOutlet weak var userField: UITextField!
    @IBOutlet weak var keyField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        userField.text = UserDefaults.standard.string(forKey: "user")
        keyField.text = UserDefaults.standard.string(forKey: "key")
    }

    /// Updates the stored credentials to what's typed in
    @IBAction func dismiss() {
        UserDefaults.standard.set(userField.text, forKey: "user")
        UserDefaults.standard.set(keyField.text?.components(separatedBy: .whitespaces).joined(), forKey: "key")
        dismiss(animated: true)
    }
}
