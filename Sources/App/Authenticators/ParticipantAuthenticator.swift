//
//  ParticipantAuthenticator.swift
//  
//
//  Created by Ivan Podvorniy on 22.02.2021.
//

import Vapor
import Fluent

struct ParticipantAuthenticator: BearerAuthenticator {
    typealias Participant = App.Participant
    
    func authenticate(bearer: BearerAuthorization, for req: Request) -> EventLoopFuture<Void> {
        return Participant.query(on: req.db).filter(\.$token == bearer.token).first().unwrap(or: Abort(.unauthorized)).flatMap { participant in
            req.auth.login(participant)
            return req.eventLoop.makeSucceededVoidFuture()
        }
    }
}
