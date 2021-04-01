@testable import App
import Fluent
import XCTVapor
import Crypto

final class GameAdminTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    let questionPath = "api/question"
    var user: User!
    var authHeaders: HTTPHeaders!

    var question_type_teacher: QuestionType = QuestionType.teacher
    var question_type_admin: QuestionType = QuestionType.admin

    var text_question: String = "So, how are you?"

    var answer_type_number: AnswerType = AnswerType.number
    var answer_type_word: AnswerType = AnswerType.word

    var answer_word: String = "Fine"
    var answer_number: String = "42"

    override func setUpWithError() throws {
        app = Application(.testing)
        try configure(app)
        testWorld = try TestWorld(app: app)
        try app.autoMigrate().wait()
        try self.testWorld.prepareStationsAndQuestions()
        self.user = User(fullName: "Test User", email: "game@test.com", passwordHash: "123", isAdmin: true)
        try self.user.save(on: self.app.db).wait()
        try self.authHeaders = getHeadersByUser(self.user)
    }

    override func tearDownWithError() throws {
        try app.autoRevert().wait()
        app.shutdown()
    }

    func getHeadersByUser(_ user: User) throws -> HTTPHeaders {
        let payload = try Payload(with: user)
        let accessToken = try app.jwt.signers.sign(payload)
        var headers = HTTPHeaders()
        headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        return headers
    }

    func testAddQuestion_number() throws {
        let station = try Station.query(on: app.db).first().wait()!
        let question_request_number = QuestionRequest(station_id: station.id!, text_question: text_question, answer_type: answer_type_number, answer: answer_number)
        try app.test(.POST, questionPath, headers: authHeaders, beforeRequest: { req in
            try req.content.encode(question_request_number)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let answer = try res.content.decode(QuestionResponse.self)
            XCTAssertEqual(answer.text_question, text_question)
            XCTAssertEqual(answer.answer_type, answer_type_number)
            try app.test(.GET, questionPath, beforeRequest: { req in
                try req.content.encode(QuestionId(answer.id!))
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                let answer = try res.content.decode(QuestionRequest.self)
                XCTAssertEqual(answer.text_question, text_question)
                XCTAssertEqual(answer.answer_type, answer_type_number)
                XCTAssertEqual(answer.station_id, station.id!)
            })
        })
    }
    /*
    func testAddQuestion_word() throws {
        let station = try Station.query(on: app.db).first().wait()!
        let question_request_word = QuestionRequest(station_id: station.id!, text_question: text_question, answer_type: answer_type_word, answer: answer_word)
        try app.test(.POST, questionPath, beforeRequest: { req in
            try req.content.encode(question_request_word)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let answer = try res.content.decode(QuestionResponse.self)
            XCTAssertEqual(answer.text_question, text_question)
            XCTAssertEqual(answer.answer_type, answer_type_word)
            try app.test(.GET, questionPath, beforeRequest: { req in
                try req.content.encode(answer.id!)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                let answer = try res.content.decode(QuestionResponse.self)
                XCTAssertEqual(todo.text_question, text_question)
                XCTAssertEqual(todo.answer_type, answer_type_word)
            })
        })
    }

    func testdelete() throws {
        let station = try Station.query(on: app.db).first().wait()!
        let question_request_word = QuestionRequest(station_id: station.id!, text_question: text_question, answer_type: answer_type_word, answer: answer_word)
        try app.test(.POST, questionPath, beforeRequest: { req in
            try req.content.encode(question_request_word)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let answer = try res.content.decode(QuestionResponse.self)
            XCTAssertEqual(answer.text_question, text_question)
            XCTAssertEqual(answer.answer_type, answer_type_word)
            try app.test(.GET, questionPath, beforeRequest: { req in
                try req.content.encode(answer.id!)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                let answer = try res.content.decode(QuestionResponse.self)
                XCTAssertEqual(todo.text_question, text_question)
                XCTAssertEqual(todo.answer_type, answer_type_word)
            })
        })
    }
    */
}
