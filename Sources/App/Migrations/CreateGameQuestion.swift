//
//  CreateGameQuestion.swift
//  
//
//  Created by Ivan Podvorniy on 06.03.2021.
//

import Fluent

struct CreateGameQuestion: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(GameQuestion.schema)
            .id()
            .field("question_id", .uuid, .references("questions", "id", onDelete: .cascade))
            .field("station_id", .uuid, .references("stations", "id", onDelete: .cascade))
            .field("game_id", .uuid, .references("games", "id", onDelete: .cascade))
            .create()
            
            

    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(GameQuestion.schema).delete()
    }
}
