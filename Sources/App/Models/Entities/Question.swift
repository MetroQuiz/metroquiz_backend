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
    
    @Parent(key: "station_id")
    var station: Station
    
    @Field(key: "text_question")
    var text_question: String
    
    @Enum(key: "answer_type")
    var answer_type: AnswerType
    
    @Field(key: "answer")
    var answer: String
    
    init() {}
    
    init(id: UUID? = nil, author_id: UUID, question_type: QuestionType, station_id: UUID, text_question: String, answer_type: AnswerType, answer: String) {
        self.id = id
        self.$author.id = author_id
        self.question_type = question_type
        self.$station.id = station_id
        self.text_question = text_question
        self.answer_type = answer_type
        self.answer = answer
    }
    
    func check(participant_ans: String) -> AnswerVerdict {
        let cleared_ans  = participant_ans.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".").lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        switch answer_type {
        case .number:
            if let p_number = Float(cleared_ans), let j_number = Float(answer) {
                return abs(p_number - j_number) < 0.1 ? .ok : .wrong
            }
            return .wrong_presentation
        case .word:
            if cleared_ans == "" || cleared_ans.rangeOfCharacter(from: CharacterSet.lowercaseLetters.inverted) != nil {
                return .wrong_presentation
            }
            return answer == cleared_ans ? .ok : .wrong
        case .order:
            let components = cleared_ans.components(separatedBy: .punctuationCharacters).joined(separator: " ").components(separatedBy: .whitespacesAndNewlines)
            switch components.count {
            case 0:
                return .wrong_presentation
            case 1:
                if let compressed_order = components.first {
                    let order_array = Array(compressed_order)
                    if order_array.filter({ UInt(String($0)) == nil }).count > 0 {
                        return .wrong_presentation
                    }
                    return order_array.map { UInt(String($0)) } == answer.components(separatedBy: .whitespacesAndNewlines).map { UInt($0) } ? .ok : .wrong
                }
                return .wrong_presentation
            default:
                return components.map { UInt(String($0)) } == answer.components(separatedBy: .whitespacesAndNewlines).map { UInt($0) } ? .ok : .wrong
            }
        case .pharse:
            let pharse_cleared_text = cleared_ans.components(separatedBy: .punctuationCharacters).joined(separator: " ").components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")

            return answer == pharse_cleared_text ? .ok : .wrong
        }
    }
    
}

