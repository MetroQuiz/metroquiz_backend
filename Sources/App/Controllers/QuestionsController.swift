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

    func delete(_ req: Request) throws -> EventLoopFuture<Void> {
        let question_id = try req.content.decode(UUID.self)
        let payload = try req.auth.require(Payload.self)
        return Question.query(on: req.db).filter(\.$author.$id == payload.userID).filter(\.$id == question_id).all().map { questions in
            questions.map { question in
                question.delete(on: req.db)
            }
        }
    }

    func change(_ req: Request) throws -> EventLoopFuture<Void> {
        let new_question = try req.content.decode(QuestionRequestEdit.self)
        let payload = try req.auth.require(Payload.self)
        return Question.query(on: req.db).filter(\.$author.$id == payload.userID).filter(\.$id == new_question.question_id).all().flatMap { question in
            question.station_id = new_question.station_id
            question.text_question = new_question.text_question
            question.answer_type = new_question.answer_type
            question.answer = new_question.answer
            question.update()
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
