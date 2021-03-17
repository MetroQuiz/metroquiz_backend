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
    app.middleware = .init()
    app.middleware.use(ErrorMiddleware.custom(environment: app.environment))
    
    // MARK: Model Middleware
    
    // MARK: Mailgun
    app.mailgun.configuration = .environment
    app.mailgun.defaultDomain = .sandbox
    
    // MARK: App Config
    app.config = .environment
    
    app.commands.use(IncludeMap(), as: "include_map")
    
    try routes(app)
    try migrations(app)
    try queues(app)
    try services(app)
        
}
