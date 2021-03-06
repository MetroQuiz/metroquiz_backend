import Vapor

struct QuestionRequest: Content {
    let author_id: UUID
    let station_id: UUID
    let text_question: String
    let answer_type: AnswerType
    let answer: String
    
    init(author_id: UUID,  question_type: QuestionType, station_id: UUID, text_question: String, answer_type: AnswerType, answer: String) {
        self.author_id = author_id
        self.station_id = station_id
        self.text_question = text_question
        self.answer_type = answer_type
        self.answer = answer
    }
    
    init(from question: Question) throws {
        self.init(author_id: question.$author.id, question_type: question.question_type, station_id: question.$station.id, text_question: question.text_question, answer_type: question.answer_type, answer: question.answer)
    }
}

extension Question {
    convenience init(from questionRequest: QuestionRequest) throws {
        self.init(author_id: questionRequest.author_id, question_type: .admin, station_id: questionRequest.station_id, text_question: questionRequest.text_question, answer_type: questionRequest.answer_type, answer: questionRequest.answer)
    }
}

struct QuestionResponse: Content {
    let id: UUID?
    let text_question: String
    let answer_type: AnswerType
    
    init(id: UUID? = nil, text_question: String, answer_type: AnswerType) {
        self.id = id
        self.text_question = text_question
        self.answer_type = answer_type
    }
    
    init(from question: Question) {
        self.init(id: question.id, text_question: question.text_question, answer_type: question.answer_type)
    }
}


extension Question {
    func asQuestionResponse() -> QuestionResponse {
        return QuestionResponse(id: self.id, text_question: self.text_question, answer_type: self.answer_type)
    }
}
