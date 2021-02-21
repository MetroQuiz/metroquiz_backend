import Vapor
import Fluent


struct QuestionsController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.group(UserAuthenticator()) { authenticated in
            authenticated.post("", use: add)
        }
    }
    
    func add(_ req: Request) throws -> EventLoopFuture<QuestionResponse> {
        let question_data = try req.content.decode(QuestionRequest.self)
        let question = try Question.init(from: question_data)
        return question.create(on: req.db).map {
            question.asQuestionResponse()
        }
        
    }
    

}
