//
//  LiveFeedViewController.swift
//  visionMockup
//
//  Created by Kevin Chen on 3/5/2019.
//  Copyright © 2019 New York University. All rights reserved.
//

import UIKit
import WebKit

class LiveFeedViewController: UIViewController {
    
    @IBOutlet weak var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        let url = URL(string: "https://www.youtube.com/watch?v=J-rRpO4SDtY")
        webView.load(URLRequest(url: url!))
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
