//
//  AddQuestionAuthor.swift
//  
//
//  Created by Ulyana Eskova on 20.02.2021.
//
import Fluent

struct AddQuestionAuthor: Migration {

    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("questions")
            .field("author_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .update()

    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("questions").deleteField("author_id").update()
    }
}
