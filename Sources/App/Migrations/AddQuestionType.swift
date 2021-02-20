import Fluent

struct AddQuestionType: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.enum("question_type").case("admin").case("teacher").create().flatMap { question_type  in
            database.schema("questions")
                .field("question_type", question_type, .required)
                .update()
            
        }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("questions").deleteField("question_type").update().flatMap { questions in
            database.enum("question_type").delete()
        }
    }
}
