//
//  TextViewController.swift
//  visionMockup
//
//  Created by Kevin Chen on 3/5/2019.
//  Copyright © 2019 New York University. All rights reserved.
//

import UIKit

class TextViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var speakButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func didPressSpeakButton(_ sender: Any) {
        
        speakButton.setTitle("Speaking...", for: .normal)
        speakButton.isEnabled = false
        speakButton.alpha = 0.6

        SpeechService.shared.speak(text: textView.text, voiceType: .waveNetFemale) {
            self.speakButton.setTitle("Speak", for: .normal)
            self.speakButton.isEnabled = true
            self.speakButton.alpha = 1
        }
        
    }
    
    @IBAction func onTap(_ sender: Any) {
        view.endEditing(true)
    }
    
}
