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

struct GameUUID: Content {
    let game_id: UUID
    
    init(game_id: UUID) {
        self.game_id = game_id
    }
}

struct GameAdminResponse: Content {
    let id: UUID?
    let origin_id: UUID
    let destination_id: UUID
    let pin: String
    let status: GameStatus
    let create_at: Date
    var player_count: Int
    init (player_count: Int = 0, from game: Game) {
        self.id = game.id
        self.origin_id = game.$origin.id
        self.destination_id = game.$destination.id
        self.pin = game.pin
        self.status = game.status
        self.create_at = game.create_at ?? Date()
        self.player_count = player_count
    }

}

struct AllGamesResponse: Content {
    var games: [GameAdminResponse]
    let question_amount: Int
    
    init(games: [GameAdminResponse], question_amount: Int) {
        self.games = games
        self.question_amount = question_amount
    }
}


struct GameStatusResponse: Content {
    let status: GameStatus
    
    init(status: GameStatus) {
        self.status = status
    }
}


struct GameQuestionRequest: Content {
    let station_id: UUID
    
    
    init(station_id: UUID) {
        self.station_id = station_id
    }
}


struct AnswerResponse: Content {
    let verdict: AnswerVerdict
    let score: Int
    let tickets: Int
    let train_fullness: Int
    let new_stations: [UUID]
    
    init(verdict: AnswerVerdict, score: Int, tickets: Int, train_fullness: Int, new_stations: [UUID]) {
        self.verdict = verdict
        self.score = score
        self.tickets = tickets
        self.train_fullness = train_fullness
        self.new_stations = new_stations
    }
}


struct AnswerRequest: Content {
    let text: String
    
    init(text: String) {
        self.text = text
    }
}
