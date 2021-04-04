//
//  GameParticipantController.swift
//
//
//  Created by Ivan Podvorniy on 06.03.2021.
//

import Vapor
import Fluent
import NIO

struct GameParticipantController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.post("enter", use: enter)
        
        routes.grouped(ParticipantAuthenticator()).group("game") { participant_authed in
            participant_authed.get("question", use: getQuestion)
            participant_authed.post("question", use: answerQuestion)
            participant_authed.get("", use: check)
        }
    }
    
    func check(req: Request) throws -> HTTPStatus {
        let participant = try req.auth.require(Participant.self)
        if req.application.gameWScontrollers[participant.$game.id] != nil {
            return .ok
        }
        return .notAcceptable
    }
    
    func enter(req: Request) throws -> EventLoopFuture<EnterRespnose> {
        let enterData = try req.content.decode(EnterRequest.self)
        return Game.query(on: req.db).filter(\.$pin == enterData.pin).first().unwrap(or: Abort(.notFound)).flatMap { game in
            if game.status != .lobby {
                return req.eventLoop.makeFailedFuture(Abort(.alreadyReported))
            }
            let new_participant = Participant(name: enterData.name, tickets: 0, score: 0, train_fullness: 0, game_id: game.id!)
            return new_participant.save(on: req.db).map {
                EnterRespnose(token: new_participant.token)
            }
        }
    }
    
    
    
    
    func getQuestion(req: Request) throws -> EventLoopFuture<QuestionResponse> {
        let participant = try req.auth.require(Participant.self)
        let station_id = try req.content.decode(GameQuestionRequest.self).station_id
        let participant_id = try participant.requireID()
        return try StationAvailability.query(on: req.db).filter(\.$station.$id == station_id).filter(\.$participant.$id == participant_id).first().unwrap(or: Abort(.forbidden)).flatMap { availability in
            if availability.level != .available {
                return req.eventLoop.makeFailedFuture(Abort(.alreadyReported))
            }
            return StationAvailability.query(on: req.db).filter(\.$participant.$id == participant_id).filter(\.$level == .in_process).first().flatMap {
                if $0 != nil {
                    return req.eventLoop.makeFailedFuture(Abort(.conflict))
                }
                return GameQuestion.query(on: req.db).filter(\.$station.$id == station_id).filter(\.$game.$id == participant.$game.id).first().unwrap(or: Abort(.notFound)).flatMap { question in
                    return question.$question.get(reload: true, on: req.db).map {
                        QuestionResponse(from: $0)
                    }
                }.flatMap { question_response in
                    availability.level = .in_process
                    availability.start_answer_at = Date()
                    return availability.save(on: req.db).flatMap {
                        req.queue.dispatch(AnswerDeadlineJob.self, AnswerDeadlinePayload(participant_id: participant_id, game_id: participant.$game.id), maxRetryCount: 1, delayUntil: Date(timeIntervalSinceNow: 60))
                    }.map {
                        return question_response
                    }
                    
                }
            }
            
        }
        
    }
    
    func answerQuestion(req: Request) throws -> EventLoopFuture<AnswerResponse> {
        let participant = try req.auth.require(Participant.self)
        let answer = try req.content.decode(AnswerRequest.self).text
        let participant_id = try participant.requireID()
        return try StationAvailability.query(on: req.db).filter(\.$level == AvailabilityLevel.in_process).filter(\.$participant.$id == participant_id).all().flatMap { stations in
            if stations.count >= 1 {
                return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
            }
            if let station_id = stations.first?.id {
                return GameQuestion.query(on: req.db).filter(\.$game.$id == participant.$game.id).filter(\.$station.$id == station_id).first().unwrap(or: Abort(.notFound)).flatMap { game_question in
                    let new_answer = Answer(verdict: game_question.question.check(participant_ans: answer),
                        submited_at: Date(), text: answer, author_id: participant_id, question_id: game_question.question.id!)
                    return new_answer.save(on: req.db).flatMap {
                        return Stage.query(on: req.db).filter(\.$origin.$id == game_question.$station.id).all().map { stages in
                            stages.map {stage in stage.$destination.id }
                        }.map { stations in
                            if new_answer.verdict == .ok {
                                return AnswerResponse(verdict: .ok, score: participant.score + 100, tickets: participant.tickets + 1, train_fullness: participant.train_fullness + 1, new_stations: stations)
                            }
                            else {
                                return AnswerResponse(verdict: new_answer.verdict, score: participant.score, tickets: participant.tickets, train_fullness: max(participant.train_fullness - 2, 0), new_stations: stations)
                            }
                        }
                    }
                }
            }
            return req.eventLoop.makeFailedFuture(Abort(.notAcceptable))
        }
    }
    
}


class GameWebSocketControoler {
    
    let eventLoop: EventLoop
    var web_sockets = [UUID: WebSocket]()
    var game_status: GameStatus
    
    init(_ game_status: GameStatus = .lobby, _ eventLoop: EventLoop) {
        self.eventLoop = eventLoop
        self.game_status = game_status
    }
    
    func isActive() -> Bool {
        return game_status == GameStatus.in_process
    }
    
    func finishQuestion(participant_id: UUID) -> EventLoopFuture<Void> {
        web_sockets[participant_id]?.send("finish")
        return eventLoop.makeSucceededVoidFuture()
    }
    
    func join(participant_id: UUID, ws: WebSocket) {
        web_sockets[participant_id]?.send("close")
        ws.onClose.map { _ in
            self.web_sockets[participant_id] = nil
            return
        }
        web_sockets[participant_id] = ws
        ws.send("{\"error\": false, \"action\": 0, \"data\" : {\"state\": \"\(game_status)\"}}")
    }

    func changeStatus(new_status: GameStatus) {
        self.game_status = new_status
        web_sockets.map { _, ws in
            ws.send("{\"error\": false, \"action\": 0, \"data\" : {\"state\": \"\(game_status)\"}}")
            return
        }
    }
}
