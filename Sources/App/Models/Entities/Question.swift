import Vapor
import Fluent

enum AnswerType: String, Codable {
    case number
    case pharse
    case word
    case order
}

enum QuestionType: String, Codable {
    case admin
    case teacher
}

final class Question: Model {
    static let schema = "questions"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "author_id")
    var author: User
    
    @Enum(key: "question_type")
    var question_type: QuestionType
    
    @Parent(key: "station")
    var station: Station
    
    @Field(key: "text_question")
    var text_question: String
    
    @Enum(key: "answer_type")
    var answer_type: AnswerType
    
    @Field(key: "answer")
    var answer: String
    
    init() {}
    
    init(
        id: UUID? = nil,
        author_id: UUID,
        question_type: QuestionType,
        station_id: UUID,
        text_question: String,
        answer_type: AnswerType,
        answer: String
    ) throws {
        self.id = id
        self.$author.id = author_id
        self.question_type = question_type
        self.$station.id = station_id
        self.text_question = text_question
        self.answer_type = answer_type
        self.answer = answer
    }
}

