//
//  File.swift
//  
//
//  Created by Ivan Podvorniy on 01.04.2021.
//

import Fluent
import Vapor

func loadGames(_ app: Application) throws {
    app.gameWScontrollers = try Game.query(on: app.db).filter(\.$status ~~ [GameStatus.lobby, GameStatus.in_process]).all().wait().reduce(into: [UUID: GameWebSocketControoler]()) { gameWScontrollers, game in
        try gameWScontrollers[game.requireID()] = GameWebSocketControoler(game.status, app.eventLoopGroup.next(), app.db)
    }
}
