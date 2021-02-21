import Fluent

struct CreateQuestion: Migration {
    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.enum("answer_type").case("number").case("word").case("pharse").case("order").create().flatMap { answer_type in
            database.schema("questions")
                .id()
                .field("station", .string, .required)
                .field("station_id", .uuid, .required, .references("stations", "id", onDelete: .cascade))
                .field("answer_type", answer_type, .required)
                .field("answer", .string, .required)
                .create()
            
        }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("questions").delete().flatMap { questions in
            database.enum("answer_type").delete()
        }
    }
}
