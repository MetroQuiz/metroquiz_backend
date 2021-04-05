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
        routes.get("stations", use: stations)
        routes.grouped(ParticipantAuthenticator()).group("game") { participant_authed in
            participant_authed.get("passed", use: getPassed)
            participant_authed.post("question_get", use: getQuestion)
            participant_authed.post("question", use: answerQuestion)
            participant_authed.get("", use: check)
            participant_authed.get("results", use: results)
        }
    }
    
    
    func participantsToResults(participants: [Participant]) -> [String: Int] {
        return participants.reduce(into: [String: Int]()) { result, participant in
            let summery_score = participant.score + participant.train_fullness * 50 + participant.tickets * 25
            result[participant.name] = summery_score
        }
    }
    
    func results(req: Request) throws -> EventLoopFuture<ResultResponse> {
        let participant = try req.auth.require(Participant.self)
        return Participant.query(on: req.db).filter(\.$game.$id == participant.$game.id).all().map(participantsToResults).map {
            ResultResponse(results: $0, name: participant.name)
        }
    }
    func stations(req: Request) throws -> EventLoopFuture<[Station.StationSVGResponse]> {
        return Station.query(on: req.db).all().map { stations in
            stations.map {
                Station.StationSVGResponse(svg_id: $0.svg_id, id: $0.id!)
            }
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
            return Participant.query(on: req.db).filter(\.$game.$id == game.id!).filter(\.$name == enterData.name).count().flatMap {
                if $0 != 0 {
                    return req.eventLoop.makeFailedFuture(Abort(.conflict))
                }
                let new_participant = Participant(id: UUID(), name: enterData.name, tickets: 1, score: 0, train_fullness: 2, game_id: game.id!)
                return new_participant.save(on: req.db).flatMap {
                    StationAvailability(participant_id: new_participant.id!, station_id: game.$origin.id, level: .passed).save(on: req.db).flatMap {
                        Stage.query(on: req.db).filter(\.$origin.$id == game.$origin.id).all().flatMap { stages in
                            stages.map { StationAvailability(participant_id: new_participant.id!, station_id: $0.$destination.id, level: AvailabilityLevel.available).save(on: req.db) }.flatten(on: req.eventLoop)
                        }.map {
                            EnterRespnose(token: new_participant.token)
                        }
                    }
                    
                }
            }
        }
    }
    
    
    func getPassed(req: Request) throws -> EventLoopFuture<GameInfoResponse> {
        let participant = try req.auth.require(Participant.self)
        let participant_id = try participant.requireID()
        return StationAvailability.query(on: req.db).filter(\.$level == AvailabilityLevel.passed).filter(\.$participant.$id == participant_id).with(\.$station).all().map { stations in
            GameInfoResponse(stations: stations.map { Station.StationSVGResponse(svg_id: $0.station.svg_id, id: $0.station.id! )}, score: participant.score, tickets: participant.tickets, train_fullness: participant.train_fullness)
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
                    return availability.save(on: req.db).map {
                        return question_response
                    }
                    
                }
            }
            
        }
        
    }
    
    func openNeighborns(participant_id: UUID, station_origin_id: UUID, req: Request) -> EventLoopFuture<Void> {
        return Stage.query(on: req.db).filter(\.$origin.$id == station_origin_id).all().map { stages in
            stages.map {stage in stage.$destination.id }
        }.flatMap { stations in
            stations.map { station_id in
                StationAvailability.query(on: req.db).filter(\.$station.$id == station_id).filter(\.$participant.$id == participant_id).first().flatMap { station_availability_optional -> EventLoopFuture<Void> in
                    if let station_availability = station_availability_optional {
                        return req.eventLoop.makeSucceededVoidFuture()
                    }
                    else {
                        return StationAvailability(participant_id: participant_id, station_id: station_id, level: AvailabilityLevel.available).save(on: req.db).map {}
                    }
                    
                }
            }.flatten(on: req.eventLoop)
        }
    }
    
    
    func answerQuestion(req: Request) throws -> EventLoopFuture<AnswerResponse> {
        let participant = try req.auth.require(Participant.self)
        let answer = try req.content.decode(AnswerRequest.self).text
        let participant_id = try participant.requireID()
        return try StationAvailability.query(on: req.db).filter(\.$level == AvailabilityLevel.in_process).filter(\.$participant.$id == participant_id).all().flatMap { stations in
            if stations.count > 1 {
                return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
            }
            if let station_id = stations.first?.$station.id {
                return GameQuestion.query(on: req.db).filter(\.$game.$id == participant.$game.id).filter(\.$station.$id == station_id).with(\.$question).first().unwrap(or: Abort(.notFound)).flatMap { game_question in
                    let new_answer = Answer(verdict: game_question.question.check(participant_ans: answer),
                                            submited_at: Date(), text: answer, author_id: participant_id, question_id: game_question.question.id!)
                    return new_answer.save(on: req.db).flatMap { _ in
                        self.openNeighborns(participant_id: participant_id, station_origin_id: game_question.question.$station.id, req: req)
                    }.flatMap {
                        stations.first!.level = AvailabilityLevel.passed
                        return stations.first!.save(on: req.db)
                    }.flatMap {
                        if new_answer.verdict == .ok {
                            participant.score += 100
                            participant.tickets += 1
                            participant.train_fullness += 1
                        }
                        else {
                            participant.score -= 50
                            participant.train_fullness = max(0, participant.train_fullness - 2)
                        }
                        return participant.save(on: req.db)
                    }
                    .map {
                        return AnswerResponse(verdict: new_answer.verdict, score: participant.score, tickets: participant.tickets, train_fullness: participant.train_fullness)
                    }
                }
            }
            return req.eventLoop.makeFailedFuture(Abort(.notAcceptable))
        }
    }
    
}


class GameWebSocketControoler {
    
    let eventLoop: EventLoop
    let db: Database
    var web_sockets = [UUID: WebSocket]()
    var game_status: GameStatus
    
    init(_ game_status: GameStatus = .lobby, _ eventLoop: EventLoop, _ db: Database) {
        self.eventLoop = eventLoop
        self.game_status = game_status
        self.db = db
    }
    
    func isActive() -> Bool {
        return game_status == GameStatus.in_process
    }
    
    func finishQuestion(participant_id: UUID) -> EventLoopFuture<Void> {
        return StationAvailability.query(on: self.db).filter(\.$level == AvailabilityLevel.in_process).filter(\.$participant.$id == participant_id).all().flatMap {
            $0.map {
                $0.level = .passed
                return $0.save(on: self.db)
            }.flatten(on: self.eventLoop)
            
        }
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
