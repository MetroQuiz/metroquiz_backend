//
//  File.swift
//  
//
//  Created by Ivan Podvorniy on 04.04.2021.
//

import Vapor
import Fluent
import Foundation
import AsyncKit

struct AddRandomQuestions: Command {
    struct Signature: CommandSignature {
    }
    
    var help: String {
        "Generate random question"
    }
    func run(using context: CommandContext, signature: Signature) throws {
        let stations = try Station.query(on: context.application.db).all().wait()
        for station in stations {
            try Question(author_id: User.query(on: context.application.db).first().wait()!.id!, question_type: .admin, station_id: station.id!, text_question: "test \(station.name)", answer_type: AnswerType.number, answer: "1303").save(on: context.application.db).wait()
        }
    }
    
}
