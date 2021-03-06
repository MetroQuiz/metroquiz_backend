//
//  GameDTO.swift
//  
//
//  Created by Ivan Podvorniy on 06.03.2021.
//

import Vapor
import Fluent

struct GameCreation : Content {
    let origin_id: UUID
    let destination_id: UUID
    
    init(origin_id: UUID, destination_id: UUID) {
        self.origin_id = origin_id
        self.destination_id = destination_id
    }
}

struct GameEdit : Content {
    let game_id: UUID
    let origin_id: UUID
    let destination_id: UUID
    
    init(game_id: UUID, origin_id: UUID, destination_id: UUID) {
        self.game_id = game_id
        self.origin_id = origin_id
        self.destination_id = destination_id
    }
}
