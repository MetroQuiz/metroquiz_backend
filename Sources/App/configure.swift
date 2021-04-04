import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import Mailgun
import QueuesRedisDriver

public func configure(_ app: Application) throws {
    // MARK: JWT
    let jwksString =  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJtZXRyb3F1aXoiLCJuYW1lIjoiVWxpYW5hIEVza292YSIsImlhdCI6IjIwMDIyMDIxIn0.xN-GS1G63MDbVjV9-OzA_VsB9EKUU35sjDtrK4K3_YE"
    app.jwt.signers.use(.hs256(key: jwksString))
    
    // MARK: Database
    // Configure PostgreSQL database
    var databaseName: String? = nil
    if app.environment == .testing {
        databaseName = "metroquiz_testing"
    }
    app.databases.use(
        .postgres(
            hostname: Environment.get("POSTGRES_HOSTNAME") ?? "localhost",
            username: Environment.get("POSTGRES_USERNAME") ?? "vapor",
            password: Environment.get("POSTGRES_PASSWORD") ?? "password",
            database: databaseName ?? (Environment.get("POSTGRES_DATABASE") ?? "vapor")
        ), as: .psql)
        
    // MARK: Middleware
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)

    // Only add this if you want to enable the default per-route logging
    let routeLogging = RouteLoggingMiddleware(logLevel: .info)
    app.middleware = .init()
    app.middleware.use(cors)
    app.middleware.use(routeLogging)
    app.middleware.use(ErrorMiddleware.custom(environment: app.environment))
    
    // MARK: Model Middleware
    
    // MARK: Mailgun
    app.mailgun.configuration = .environment
    app.mailgun.defaultDomain = .sandbox
    
    // MARK: App Config
    app.config = .environment
    
    // MARK: Game controller
    
    app.commands.use(IncludeMap(), as: "include_map")
    try loadGames(app)
    try routes(app)
    try migrations(app)
    try queues(app)
    try services(app)
    
    app.webSocket("ws") { req, ws in
        ws.onText { ws, text in
            Participant.query(on: req.db).filter(\.$token == text).first().map { participant_optional in
                if let participant = participant_optional {
                    if let gameWSController = req.application.gameWScontrollers[participant.$game.id] {
                        gameWSController.join(participant_id: participant.id!, ws: ws)
                        
                    }
                    else {
                        ws.send("{\"error\": true, \"message\": \"No such game\"}")
                        ws.close()
                    }
                }
                else {
                    ws.send("{\"error:\" true, \"message\": \"Auth failed\"}")
                    ws.close()
                }
            }
        }
    }
        
}

extension Application {
    struct GameWSControllerKey: StorageKey {
        typealias Value = [UUID: GameWebSocketControoler]
    }
    
    var gameWScontrollers: [UUID: GameWebSocketControoler] {
        get {
            storage[GameWSControllerKey.self] ?? [UUID: GameWebSocketControoler]()
        }
        set {
            storage[GameWSControllerKey.self] = newValue
        }
    }
}
