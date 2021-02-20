//
//  File.swift
//
//
//  Created by Ulyana Eskova on 20.02.2021.
//

import Vapor
import Fluent



struct IncludeMap: Command {
    struct Signature: CommandSignature {
        @Argument(name: "map_file")
        var map_file: String
        
        
    }
    
    var help: String {
        "Command to include map"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let fileURL = dir.appendingPathComponent("../" + signature.map_file)
        
            do {
                let jsonString = try String(contentsOf: fileURL, encoding: .utf8)
                if let map = try! JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!, options: .allowFragments) as? [[String: Any]] {
                    print(map)
                }
            }
            catch {/* error handling here */}
        }
    }
}

