@testable import App
import Fluent
import XCTVapor
import XCTQueues

class TestWorld {
    let app: Application
    
    // Repositories
    private var tokenRepository: TestRefreshTokenRepository
    private var userRepository: TestUserRepository
    private var emailTokenRepository: TestEmailTokenRepository
    private var passwordTokenRepository: TestPasswordTokenRepository
    
    private var refreshtokens: [RefreshToken] = []
    private var users: [User] = []
    private var emailTokens: [EmailToken] = []
    private var passwordTokens: [PasswordToken] = []
    
    init(app: Application) throws {
        self.app = app
        try app.autoRevert().wait()
        try app.autoMigrate().wait()

        try app.jwt.signers.use(.es256(key: .generate()))
        
        self.tokenRepository = TestRefreshTokenRepository(tokens: refreshtokens, eventLoop: app.eventLoopGroup.next())
        self.userRepository = TestUserRepository(users: users, eventLoop: app.eventLoopGroup.next())
        self.emailTokenRepository = TestEmailTokenRepository(tokens: emailTokens, eventLoop: app.eventLoopGroup.next())
        self.passwordTokenRepository = TestPasswordTokenRepository(tokens: passwordTokens, eventLoop: app.eventLoopGroup.next())
        
        app.repositories.use { _ in self.tokenRepository }
        app.repositories.use { _ in self.userRepository }
        app.repositories.use { _ in self.emailTokenRepository }
        app.repositories.use { _ in self.passwordTokenRepository }
        
        app.queues.use(.test)
        app.mailgun.use(.fake)
        app.config = .init(frontendURL: "http://frontend.local", apiURL: "http://api.local", noReplyEmail: "no-reply@testing.local")
    }
    
    
    func prepareStationsAndQuestions() throws {
        try IncludeMap.run(application: app, map_file: Environment.get("MAP_PATH")!) { text in
            debugPrint(text)
        }
        let user = User(fullName: "Question User", email: "question@test.com", passwordHash: "123", isAdmin: true)
        try user.save(on: app.db).wait()
        try Station.query(on: app.db).all().flatMap { stations in
            [stations.map { station in
                let new_question = Question(author_id: user.id!, question_type: QuestionType.admin, station_id: station.id!, text_question: "WHY? WHAT?", answer_type: AnswerType.number, answer: "1")
                return new_question.save(on: self.app.db)
            }.flatten(on: self.app.eventLoopGroup.next()), stations.map { station in
                let new_question = Question(author_id: user.id!, question_type: QuestionType.admin, station_id: station.id!, text_question: "WHY? WHAT?", answer_type: AnswerType.number, answer: "1")
                return new_question.save(on: self.app.db)
            }.flatten(on: self.app.eventLoopGroup.next())].flatten(on: self.app.eventLoopGroup.next())
    
        }.wait()
    }
    
}


