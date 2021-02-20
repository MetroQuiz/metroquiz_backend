import Vapor

struct QuestionRequest: Content {
    let id: UUID?
    let author_id: User
    let question_type: QuestionType
    let station: Station
    let text_question: String
    let answer_type: AnswerType
    let answer: String
    
    init(id: UUID? = nil, author_id: User, question_type: QuestionType, station: Station, text_question: String, answer_type: AnswerType, answer: String) {
        self.id = id
        self.author_id = author_id
        self.question_type = question_type
        self.station = station
        self.text_question = text_question
        self.answer_type = answer_type
        self.answer = answer
    }
    
    init(from question: Question) {
        self.init(id: question.id, author_id: question.author_id, question_type: question.question_type, station: question.station, text_question: question.text_question, answer_type: question.answer_type, answer: question.answer)
    }
}


