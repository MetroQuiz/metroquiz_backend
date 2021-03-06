import Vapor
import Fluent


struct QuestionsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.group(UserAuthenticator()) { authenticated in
            authenticated.post("", use: add)
            authenticated.patch("", use: change)
            authenticated.delete("", use: delete)
            authenticated.get("by_station", use: getByStation)
            authenticated.get("by_id", use: getByID)
            authenticated.get("by_id_admin", use: getByID_admin)
        }
    }
    
    func add(_ req: Request) throws -> EventLoopFuture<QuestionResponse> {
        let author_id = try req.auth.require(Payload.self)
        let question_data = try req.content.decode(QuestionRequest.self)
        let question = try Question.init(from: question_data, author_id: author_id.userID)
        return question.create(on: req.db).map {
            question.asQuestionResponse()
        }
    }

    func delete(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let question_id = try req.content.decode(UUID.self)
        let payload = try req.auth.require(Payload.self)
        return Question.query(on: req.db).filter(\.$author.$id == payload.userID).filter(\.$id == question_id).first().unwrap(or: Abort(.notFound)).flatMap { question in
            question.delete(on: req.db)
        }.transform(to: .ok)
    }

    func change(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let new_question = try req.content.decode(QuestionRequestEdit.self)
        let payload = try req.auth.require(Payload.self)
        return Question.query(on: req.db).filter(\.$author.$id == payload.userID).filter(\.$id == new_question.question_id).first().unwrap(or: Abort(.notFound)).flatMap { question -> EventLoopFuture<HTTPStatus> in
            question.$station.id = new_question.station_id
            question.text_question = new_question.text_question
            question.answer_type = new_question.answer_type
            question.answer = new_question.answer
            return question.update(on: req.db).map { _ in
                HTTPStatus.ok
            }
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

    func getByID(_ req: Request) throws -> EventLoopFuture<QuestionResponse> {
        let question_id = try req.content.decode(UUID.self)
        return Question.query(on: req.db).with(\.$station).filter(\.$id == question_id).first().unwrap(or: Abort(.notFound)).map { question in
            question.asQuestionResponse()
        }
    }

    func getByID_admin(_ req: Request) throws -> EventLoopFuture<QuestionRequest> {
        let question_id = try req.content.decode(UUID.self)
        return Question.query(on: req.db).with(\.$station).filter(\.$id == question_id).first().unwrap(or: Abort(.notFound)).flatMapThrowing { question in
            try question.asQuestionRequest()
        }
    }
}
