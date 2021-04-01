import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.group("api") { api in
        // Authentication
        try! api.register(collection: AuthenticationController())
        // Question
        try! api.register(collection: QuestionsController())
    }
}
