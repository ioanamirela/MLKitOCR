//
//  InfoExtractor.swift
//  MLKitOCR
//
//  Created by Brooks, Ioana on 8/2/18.
//  Copyright © 2018 Brooks, Ioana. All rights reserved.
//

import UIKit

class InfoExtractor {
    
    //Regex for Regence and Moda member id/group number
    var groupNumberRegex = "^[0-9]{8}$"
    var memberIdRegex = "^[A-Z]+[0-9]{7,9}$"
    var memberIdNumbersRegex = "[0-9]{7,9}$"
    
    func matches(for regex: String, in text: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            let finalResult = results.map {
                String(text[Range($0.range, in: text)!])
            }
            return finalResult
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}
