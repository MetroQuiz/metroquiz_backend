//
//  GameAdminController.swift
//  
//
//  Created by Ivan Podvorniy on 06.03.2021.
//

import Vapor
import Fluent


struct GameAdminController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.grouped(UserAuthenticator()).group("admin") { routes in
            routes.post("", use: add)
        }
    }
    
    func add(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let author_id = try req.auth.require(Payload.self).userID
        let gameData = try req.content.decode(GameCreation.self)
        return [Station.find(gameData.destination_id, on: req.db).unwrap(or: Abort(.notFound)),
                Station.find(gameData.destination_id, on: req.db).unwrap(or: Abort(.notFound))].flatten(on: req.eventLoop.next()).flatMap { _ in
                    return Game(from: gameData, author_id: author_id, db: req.db).save(on: req.db).map { _ -> HTTPStatus in
                        .ok
                    }
                }
       
    }
    
    func change(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let author_id = try req.auth.require(Payload.self).userID
        let gameData = try req.content.decode(GameEdit.self)
        return [Station.find(gameData.destination_id, on: req.db).unwrap(or: Abort(.notFound)),
                Station.find(gameData.destination_id, on: req.db).unwrap(or: Abort(.notFound))].flatten(on: req.eventLoop.next()).flatMap { _ in
                    return Game.find(gameData.game_id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { game -> EventLoopFuture<HTTPStatus> in
                        game.$destination.id = gameData.destination_id
                        game.$origin.id = gameData.origin_id
                        return game.update(on: req.db).map { _ in
                            HTTPStatus.ok
                        }
                    }
                }
    }
    
}
