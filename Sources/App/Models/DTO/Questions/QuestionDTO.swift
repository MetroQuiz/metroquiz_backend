import Vapor

struct QuestionRequest: Content {
    let question_type: QuestionType
    let station_id: UUID
    let text_question: String
    let answer_type: AnswerType
    let answer: String
    
    init(question_type: QuestionType, station_id: UUID, text_question: String, answer_type: AnswerType, answer: String) {
        self.station_id = station_id
        self.text_question = text_question
        self.question_type = question_type
        self.answer_type = answer_type
        self.answer = answer
    }
}

extension Question {
    convenience init(from questionRequest: QuestionRequest, author_id: UUID) throws {
        self.init(author_id: author_id, question_type: .admin, station_id: questionRequest.station_id, text_question: questionRequest.text_question, answer_type: questionRequest.answer_type, answer: questionRequest.answer)
    }
}

extension Question {
    func asQuestionRequest() -> QuestionRequest {
        return QuestionRequest(question_type: self.question_type, station_id: self.$station.id, text_question: self.text_question, answer_type: self.answer_type, answer: self.answer)
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

struct QuestionRequestEdit: Content {
    let question_id: UUID?
    let station_id: UUID
    let text_question: String
    let answer_type: AnswerType
    let answer: String

    init(question_id: UUID?, station_id: UUID, text_question: String, answer_type: AnswerType, answer: String) {
        self.question_id = question_id
        self.station_id = station_id
        self.text_question = text_question
        self.answer_type = answer_type
        self.answer = answer
    }
}

extension Question {
    func asQuestionEdit() -> QuestionRequestEdit {
        return QuestionRequestEdit(question_id: self.id, station_id: self.$station.id, text_question: self.text_question, answer_type: self.answer_type, answer: self.answer)
    }
}