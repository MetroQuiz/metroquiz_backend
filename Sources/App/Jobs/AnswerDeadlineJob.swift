//
//  File.swift
//  
//
//  Created by Ivan Podvorniy on 01.04.2021.
//

import Vapor
import Fluent
import Queues
import Mailgun

struct AnswerDeadlinePayload: Codable {
    let participant_id: UUID
    let game_id: UUID
}
struct AnswerDeadlineJob: Job {
    func dequeue(_ context: QueueContext, _ payload: AnswerDeadlinePayload) -> EventLoopFuture<Void> {
        return StationAvailability.query(on: context.db).filter(\.$participant.$id == payload.participant_id).all().flatMap { stations in
            stations.map { station in
                station.level = .passed
                return station.save(on: context.db)
            }.flatten(on: context.eventLoop)
        }.flatMap { _ in
            if let gameWSController = context.application.gameWScontrollers[payload.game_id] {
                return gameWSController.finishQuestion(participant_id: payload.participant_id)
            }
            return context.eventLoop.makeFailedFuture(Abort(.notAcceptable))
        }
        
    }
    
    typealias Payload = AnswerDeadlinePayload
    
}

