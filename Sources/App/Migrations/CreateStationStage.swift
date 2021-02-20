//
//  File.swift
//  
//
//  Created by Ulyana Eskova on 20.02.2021.
//

import Fluent

struct CreateStationsAndStages: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("stations")
            .id()
            .field("name", .string, .required)
            .field("line_color", .string, .required)
            .field("svg_id", .string, .required)
            .create().flatMap { _ in
            database.enum("stage_type").case("span").case("change").case("ground_change").create().flatMap { stage_type in
                database.schema("stages")
                    .id()
                    .field("origin_id", .uuid, .required, .references("stations", "id", onDelete: .cascade))
                    .field("destination_id", .uuid, .required, .references("stations", "id", onDelete: .cascade))
                    .field("stage_type", stage_type, .required)
                    .create()
                
                
            }
        }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("stages").delete().flatMap { questions in
            database.enum("stage_type").delete().flatMap { _ in
                database.schema("stations").delete()
            }
        }
    }
}
