//
//  CreateGame.swift
//  
//
//  Created by Ivan Podvorniy on 21.02.2021.
//

import Fluent
import Vapor


struct CreateGame: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.enum("game_state").case("preparing").case("lobby").case("in_process").case("end").create().flatMap { game_state in
            database.schema(Game.schema)
                .id()
                .field("author_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
                .field("pin", .string, .required)
                .field("origin_id", .uuid, .required, .references("stations", "id", onDelete: .cascade))
                .field("destination_id", .uuid, .required, .references("stations", "id", onDelete: .cascade))
                .field("state", game_state, .required)
                .field("create_at", .date)
                .unique(on: "pin")
                .create()
            
        }.flatMap {
            database.schema(Participant.schema)
                .id()
                .field("token", .string, .required)
                .field("tickets", .uint, .required)
                .field("score", .uint, .required)
                .field("train_fullness", .uint, .required)
                .field("game_id", .uuid, .required, .references("games", "id", onDelete: .cascade))
                .create()
        }.flatMap {
            return [database.enum("answer_verdict").case("ok").case("wrong").case("wrong_presentation").create().flatMap { answerVerdict in
                database.schema(Answer.schema)
                        .id()
                        .field("text", .string, .required)
                        .field("verdict", answerVerdict)
                        .field("author_id", .uuid, .required, .references("participants", "id", onDelete: .cascade))
                        .field("question_id", .uuid, .required, .references("questions", "id", onDelete: .cascade))
                        .field("submited_at", .date)
                    .create()},
                    database.enum("availability_level").case("in_process").case("passed").case("available").create().flatMap { availability_level in
                        database.schema(StationAvailability.schema)
                            .id()
                            .field("participant_id", .uuid, .required, .references("participants", "id", onDelete: .cascade))
                            .field("station_id", .uuid, .required, .references("stations", "id", onDelete: .cascade))
                            .field("level", availability_level, .required)
                            .field("submited_at", .date)
                            .create()
                    }].flatten(on: database.eventLoop)
        }
        
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return [database.schema(StationAvailability.schema).delete().flatMap {
            database.enum("availability_level").delete()
        }, database.schema(Answer.schema).delete()].flatten(on: database.eventLoop).flatMap {
            database.schema(Participant.schema).delete()
        }.flatMap {
            database.schema(Game.schema).delete()
        }.flatMap {
            database.enum("game_state").delete()
        }
    }
}

