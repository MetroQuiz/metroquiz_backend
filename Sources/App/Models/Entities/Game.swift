import Vapor
import Fluent


enum GameStatus: String, Codable, Content {
    case preparing
    case lobby
    case in_process
    case end
}


enum AvailabilityLevel: String, Codable {
    case passed
    case available
}


final class Participant: Model, Authenticatable {
    static let schema = "participants"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "token")
    var token: String
    
    @Field(key: "tickets")
    var tickets: UInt
    
    @Field(key: "score")
    var score: UInt
    
    @Field(key: "train_fullness")
    var train_fullness: UInt
    
    @Parent(key: "game_id")
    var game: Game
    
    init() {}
    
    init(id : UUID? = nil, token: String = Participant.generateToken(), tickets: UInt, score: UInt, train_fullness: UInt, game_id: UUID) {
        self.id = id
        self.token = token
        self.tickets = tickets
        self.score = score
        self.train_fullness = train_fullness
        self.$game.id = game_id
    }
    
    static func generateToken() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map{ _ in letters.randomElement()! })
    }
}


final class Answer: Model {
    static let schema = "answers"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "text")
    var text: String
    
    @Field(key: "is_correct")
    var is_correct: Bool?
    
    @Parent(key: "question_id")
    var question: Question
    
    @Parent(key: "author_id")
    var author: Participant
    
    @Timestamp(key: "submited_at", on: .create)
    var submited_at: Date?
    
    init() {}
    
    init(id: UUID? = nil, is_correct: Bool? = nil, submited_at: Date? = nil, text: String, author_id: UUID, question_id: UUID) {
        self.id = id
        self.is_correct = is_correct
        self.submited_at = submited_at
        self.$author.id = author_id
        self.$question.id = question_id
    }
    
}

final class StationAvailability: Model {
    static let schema = "stations_availability"

    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "participant_id")
    var participant: Participant
    
    @Parent(key: "station_id")
    var station: Station
    
    @Enum(key: "level")
    var level: AvailabilityLevel
    
    
    init() {}
    
    init(id: UUID? = nil, participant_id: UUID, station_id: UUID, level: AvailabilityLevel) {
        self.id = id
        self.$participant.id = participant_id
        self.$station.id = station_id
        self.level = level
    }
    
}


final class GameQuestion: Model {
    static let schema = "game_questions"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "station_id")
    var station: Station
    
    @Parent(key: "question_id")
    var question: Question

    @Parent(key: "game_id")
    var game: Game
    
    
    init() {}
    
    init(id: UUID? = nil, station_id: UUID, question_id: UUID, game_id: UUID) {
        self.id = id
        self.$station.id = station_id
        self.$question.id = question_id
        self.$game.id = game_id
    }
    
}


final class Game: Model {
    static let schema = "games"
        
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "author_id")
    var author: User
    
    @Field(key: "pin")
    var pin: String
    
    @Parent(key: "origin_id")
    var origin: Station
    
    @Parent(key: "destination_id")
    var destination: Station
        
    @Enum(key: "state")
    var status: GameStatus
    
    @Siblings(through: GameQuestion.self, from: \.$game, to: \.$question)
    var questions: [Question]
    
    init() {}
    
    init(id : UUID? = nil, author_id: UUID, pin: String, origin_id: UUID, destination_id: UUID, status: GameStatus) {
        self.id = id
        self.$author.id = author_id
        self.pin = pin
        self.$origin.id = origin_id
        self.$destination.id = destination_id
        self.status = status
    }
    
    static func generatePin() -> String {
        var result = ""
        for _ in 0..<8 {
            result.append(String(Int.random(in: 1...9)))
        }
        return result
    }
    
    static func fromGameCreation(from gameCreation: GameCreation, author_id: UUID, req: Request) -> EventLoopFuture<Game> {
        let newGame = Game(author_id: author_id, pin: Game.generatePin(), origin_id: gameCreation.origin_id, destination_id: gameCreation.destination_id, status: .preparing)
        return newGame.save(on: req.db).flatMap { _ in
            return Question.query(on: req.db).with(\.$station).all().flatMap { questions -> EventLoopFuture<Void> in
                var result = [UUID: UUID]()
                
                for question in questions.shuffled() {
                    if let station_id = question.station.id, let question_id = question.id {
                        result[station_id] = question_id
                    }
                }
                return result.map { (station_id, question_id) in
                    if let game_id = newGame.id {
                        return GameQuestion(station_id: station_id, question_id: question_id, game_id: game_id).save(on: req.db)
                    }
                    else {
                        return req.eventLoop.makeFailedFuture(Abort(.conflict))
                    }
                }.flatten(on: req.eventLoop)
            }.map {
                newGame
            }
        }
    }
    
}

