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
                Station.find(gameData.destination_id, on: req.db).unwrap(or: Abort(.notFound))].flatten(on: req.eventLoop.next()).flatMap { stations in
                    return Game.query(on: req.db).filter(\.$id == gameData.game_id).filter(\.$author.$id == author_id).first().unwrap(or: Abort(.forbidden)).flatMap { game in
                        game.$origin.id = gameData.origin_id
                        game.$destination.id = gameData.destination_id
                        return game.update(on: req.db).map { _ in
                            HTTPStatus.ok
                        }
                    }
                }
    }
    
    
    func toggle_status(req: Request) throws -> EventLoopFuture<GameStatus> {
        let author_id = try req.auth.require(Payload.self).userID
        let game_id = try req.content.decode(UUID.self)
        return Game.query(on: req.db).filter(\.$id == game_id).filter(\.$author.$id == author_id).first().unwrap(or: Abort(.forbidden)).flatMap { game in
            switch game.status {
            case .end:
                game.status = .in_process
                return game.update(on: req.db).map { _ in
                    GameStatus.in_process
                }
            case .in_process:
                game.status = .end
                return game.update(on: req.db).map { _ in
                    GameStatus.end
                }
            case .lobby:
                game.status = .in_process
                return game.update(on: req.db).map { _ in
                    GameStatus.in_process
                }
            case .preparing:
                game.status = .lobby
                return game.update(on: req.db).map { _ in
                    GameStatus.lobby
                }
            }
            
            
        }
    }
    
}
