//
//  AddParticipantName.swift
//  
//
//  Created by Ivan Podvorniy on 03.04.2021.
//

import Fluent

struct AddParticipantName: Migration {

    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Participant.schema).field("name", .string, .required).update()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Participant.schema).deleteField("name").update()
    }
}
