import Vapor
import Fluent


struct QuestionsController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.group(UserAuthenticator()) { authenticated in
            authenticated.post("", use: add)
            authenticated.get("by_station", use: getByStation)
        }
    }
    
    func add(_ req: Request) throws -> EventLoopFuture<QuestionResponse> {
        let question_data = try req.content.decode(QuestionRequest.self)
        let question = try Question.init(from: question_data)
        return question.create(on: req.db).map {
            question.asQuestionResponse()
        }
    }
    
    func getByStation(_ req: Request) throws -> EventLoopFuture<[QuestionResponse]> {
        let station = try req.content.decode(UUID.self)
        return Question.query(on: req.db).with(\.$station).filter(\.$station.$id == station).all().map { questions in
            questions.map { question in
                question.asQuestionResponse()
            }
        }
    }
    

}
