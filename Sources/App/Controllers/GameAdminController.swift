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
            routes.patch("", use: change)
            routes.post("toggle_status", use: toggle_status)
            routes.get("", use: get)
        }
    }
    
    func get(req: Request) throws -> EventLoopFuture<GameAdminResponse> {
        let author_id = try req.auth.require(Payload.self).userID
        let game_id = try req.content.decode(GameUUID.self).game_id
        return Game.find(game_id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { game in
            if game.$author.id != author_id {
                return req.eventLoop.makeFailedFuture(Abort(.forbidden))
            }
            return req.eventLoop.makeSucceededFuture(GameAdminResponse(from: game))
        }
    }
    
    func add(req: Request) throws -> EventLoopFuture<GameAdminResponse> {
        let author_id = try req.auth.require(Payload.self).userID
        let gameData = try req.content.decode(GameCreation.self)
        if (gameData.destination_id == gameData.origin_id) {
            return req.eventLoop.makeFailedFuture(Abort(.conflict))
        }
        return [Station.find(gameData.destination_id, on: req.db).unwrap(or: Abort(.notFound)),
                Station.find(gameData.destination_id, on: req.db).unwrap(or: Abort(.notFound))].flatten(on: req.eventLoop.next()).flatMap { _ in
                    return Game.fromGameCreation(from: gameData, author_id: author_id, db: req.db).flatMap { game in
                        return game.save(on: req.db).map {
                            GameAdminResponse(from: game)
                        }
                    }
                }
        
    }
    
    func change(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let author_id = try req.auth.require(Payload.self).userID
        let gameData = try req.content.decode(GameEdit.self)
        if (gameData.destination_id == gameData.origin_id) {
            return req.eventLoop.makeFailedFuture(Abort(.conflict))
        }
        return [Station.find(gameData.destination_id, on: req.db).unwrap(or: Abort(.notFound)),
                Station.find(gameData.destination_id, on: req.db).unwrap(or: Abort(.notFound))].flatten(on: req.eventLoop.next()).flatMap { stations in
                    return Game.find(gameData.game_id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { game in
                        if game.$author.id != author_id {
                            return req.eventLoop.makeFailedFuture(Abort(.forbidden))
                        }
                        game.$origin.id = gameData.origin_id
                        game.$destination.id = gameData.destination_id
                        return game.update(on: req.db).map { _ in
                            HTTPStatus.ok
                        }
                    }
                }
    }
    
    
    func toggle_status(req: Request) throws -> EventLoopFuture<GameStatusResponse> {
        let author_id = try req.auth.require(Payload.self).userID
        let game_id = try req.content.decode(GameUUID.self).game_id
        return Game.find(game_id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { game in
            if game.$author.id != author_id {
                return req.eventLoop.makeFailedFuture(Abort(.forbidden))
            }
            switch game.status {
            case .end:
                game.status = .in_process
                return game.update(on: req.db).map { _ in
                    GameStatusResponse(status: GameStatus.in_process)
                }
            case .in_process:
                game.status = .end
                return game.update(on: req.db).map { _ in
                    GameStatusResponse(status: GameStatus.end)
                }
            case .lobby:
                game.status = .in_process
                return game.update(on: req.db).map { _ in
                    GameStatusResponse(status: GameStatus.in_process)
                }
            case .preparing:
                game.status = .lobby
                return game.update(on: req.db).map { _ in
                    GameStatusResponse(status: GameStatus.lobby)
                }
            }
            
            
        }
    }
    
}
