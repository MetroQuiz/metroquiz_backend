//
//  File.swift
//  
//
//  Created by Ivan Podvorniy on 17.03.2021.
//


import Vapor
import Fluent

struct EnterRequest: Content {
    let pin: String
    let name: String
    
    init(pin: String, name: String) {
        self.pin = pin
        self.name = name
    }
}

struct EnterRespnose : Content {
    let token: String
    
    init(token: String) {
        self.token = token
    }
}

