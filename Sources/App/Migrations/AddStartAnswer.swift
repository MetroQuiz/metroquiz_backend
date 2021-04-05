//
//  File.swift
//  
//
//  Created by Ivan Podvorniy on 04.04.2021.
//

import Fluent

struct AddStartAnswer: Migration {

    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(StationAvailability.schema).field("start_answer", .date).update()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(StationAvailability.schema).deleteField("start_answer").update()
    }
}
