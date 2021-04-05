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
            routes.get("me", use: me)
            routes.get("stations", use: stations)
        }
    }
    
    
    func stations(req: Request) throws -> EventLoopFuture<[Station.StationResponse]> {
        return Station.query(on: req.db).all().map { stations in
            stations.map {
                Station.StationResponse(name: $0.name, id: $0.id!)
            }
        }
    }
    
    func webSocket(req: Request, ws: WebSocket) {
        ws.send("Hi")
        ws.close()
    }
    
    
    
    func me(req: Request) throws -> EventLoopFuture<AllGamesResponse> {
        let author_id = try req.auth.require(Payload.self).userID
        return Game.query(on: req.db).filter(\.$author.$id == author_id).sort(\.$create_at).all().flatMap { games in
            
            games.map { game in
                return Participant.query(on: req.db).filter(\.$game.$id == game.id!).count()
            }.flatten(on: req.eventLoop).flatMap { counts in
                var gameResp = [GameAdminResponse]()
                for i in (0..<counts.count).reversed() {
                    gameResp.append(GameAdminResponse(player_count: counts[i], from: games[i]))
                }
                return Question.query(on: req.db).count().map {
                    return AllGamesResponse(games: gameResp, question_amount: $0)
                }
                
            }
        
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
                    return Game.fromGameCreation(from: gameData, author_id: author_id, req: req).flatMap { game in
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
                if let gameWSController = req.application.gameWScontrollers[game_id] {
                    game.status = .in_process
                    gameWSController.changeStatus(new_status: game.status)
                    return game.update(on: req.db).map { _ in
                        GameStatusResponse(status: GameStatus.in_process)
                    }
                }
                return req.eventLoop.makeFailedFuture(Abort(.notAcceptable))
            case .in_process:
                if let gameWSController = req.application.gameWScontrollers[game_id] {
                    game.status = .end
                    gameWSController.changeStatus(new_status: game.status)
                    return game.update(on: req.db).map { _ in
                        GameStatusResponse(status: GameStatus.end)
                    }
                }
                return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
            case .lobby:
                if let gameWSController = req.application.gameWScontrollers[game_id] {
                    game.status = .in_process
                    gameWSController.changeStatus(new_status: game.status)
                    return game.update(on: req.db).map { _ in
                        GameStatusResponse(status: GameStatus.in_process)
                    }
                }
                return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
            case .preparing:
                game.status = .lobby
                req.application.gameWScontrollers[game_id] = GameWebSocketControoler(.lobby,  req.application.eventLoopGroup.next(), req.db)
                return game.update(on: req.db).map { _ in
                    GameStatusResponse(status: GameStatus.lobby)
                }
            }
            
            
        }
    }
    
}
