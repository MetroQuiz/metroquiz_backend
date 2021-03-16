//
//  GameAdminTests.swift
//  
//
//  Created by Ivan Podvorniy on 16.03.2021.
//

@testable import App
import Fluent
import XCTVapor
import Crypto

final class GameAdminTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    let adminPath = "api/admin"
    var user: User!
    var authHeaders: HTTPHeaders!
    override func setUpWithError() throws {
        app = Application(.testing)
        try configure(app)
        testWorld = try TestWorld(app: app)
        try app.autoMigrate().wait()
        try self.testWorld.prepareStationsAndQuestions()
        self.user = User(fullName: "Test User", email: "game@test.com", passwordHash: "123", isAdmin: true)
        try self.user.save(on: self.app.db).wait()
        try self.authHeaders = getHeadersByUser(self.user)
    }
    
    override func tearDownWithError() throws {
        try app.autoRevert().wait()
        app.shutdown()
    }
    
    func getHeadersByUser(_ user: User) throws -> HTTPHeaders {
        let payload = try Payload(with: user)
        let accessToken = try app.jwt.signers.sign(payload)
        var headers = HTTPHeaders()
        headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        return headers
    }
    
    func testGameCreation() throws {
        let stations = try Station.query(on: app.db).all().wait()
        let gameCreation = try GameCreation(origin_id: stations[0].id!, destination_id: stations[1].id!)
        let payload = try Payload(with: user)
        let accessToken = try app.jwt.signers.sign(payload)
        var headers = HTTPHeaders()
        headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        try app.test(.POST, adminPath, headers: authHeaders, beforeRequest: { req in
            try req.content.encode(gameCreation)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContent(GameAdminResponse.self, res) { game in
                XCTAssertEqual(game.status, .preparing)
                XCTAssertTrue(try! NSRegularExpression(pattern: "[0-9]{8}").matches(game.pin))
                XCTAssertEqual(game.origin_id, stations[0].id!)
                XCTAssertEqual(game.destination_id, stations[1].id!)
            }
        })
    }
    
    
    func testGameView() throws {
        let stations = try Station.query(on: app.db).all().wait()
        let gameCreation = try GameCreation(origin_id: stations[0].id!, destination_id: stations[1].id!)
        let payload = try Payload(with: user)
        let accessToken = try app.jwt.signers.sign(payload)
        var headers = HTTPHeaders()
        headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        
        try app.test(.POST, adminPath, headers: authHeaders, beforeRequest: { req in
            try req.content.encode(gameCreation)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            try XCTAssertContent(GameAdminResponse.self, res) { game in
                XCTAssertEqual(game.status, .preparing)
                XCTAssertTrue(try! NSRegularExpression(pattern: "[0-9]{8}").matches(game.pin))
                XCTAssertEqual(game.origin_id, stations[0].id!)
                XCTAssertEqual(game.destination_id, stations[1].id!)
                let stations = try Station.query(on: app.db).all().wait()
                
                let gameUUID = GameUUID(game_id: game.id!)
                try app.test(.GET, adminPath, headers: authHeaders, beforeRequest: { req in
                    try req.content.encode(gameUUID)
                }, afterResponse: { res in
                    XCTAssertEqual(res.status, .ok)
                    try XCTAssertContent(GameAdminResponse.self, res) { now_game in
                        XCTAssertEqual(now_game.status, game.status)
                        XCTAssertEqual(now_game.pin, game.pin)
                        XCTAssertEqual(now_game.origin_id, game.origin_id)
                        XCTAssertEqual(now_game.destination_id, game.destination_id)
                    }
                })
            }
            
        })
    }
    
    func testSameStation() throws {
        let station = try Station.query(on: app.db).first().wait()!
        
        let gameCreation = try GameCreation(origin_id: station.id!, destination_id: station.id!)
        
        try app.test(.POST, adminPath, headers: authHeaders, beforeRequest: { req in
            try req.content.encode(gameCreation)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .conflict)
            
        })
    }
    
    func testSameStationEdit() throws {
        let stations = try Station.query(on: app.db).all().wait()
        let gameCreation = try GameCreation(origin_id: stations[0].id!, destination_id: stations[1].id!)
        let payload = try Payload(with: user)
        let accessToken = try app.jwt.signers.sign(payload)
        var headers = HTTPHeaders()
        headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        
        try app.test(.POST, adminPath, headers: authHeaders, beforeRequest: { req in
            try req.content.encode(gameCreation)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            try XCTAssertContent(GameAdminResponse.self, res) { game in
                XCTAssertEqual(game.status, .preparing)
                XCTAssertTrue(try! NSRegularExpression(pattern: "[0-9]{8}").matches(game.pin))
                XCTAssertEqual(game.origin_id, stations[0].id!)
                XCTAssertEqual(game.destination_id, stations[1].id!)
                let station = try Station.query(on: app.db).first().wait()!
                
                let gameEdit = try GameEdit(game_id: game.id!, origin_id: station.id!, destination_id: station.id!)
                
                try app.test(.PATCH, adminPath, headers: authHeaders, beforeRequest: { req in
                    try req.content.encode(gameEdit)
                }, afterResponse: { res in
                    XCTAssertEqual(res.status, .conflict)
                    
                })
            }
            
        })
    }
    
    func testNonExistentStationCreation() throws {
        let stations = try Station.query(on: app.db).all().wait()
        let gameCreation = try GameCreation(origin_id: stations[0].id!, destination_id: UUID())
        let payload = try Payload(with: user)
        let accessToken = try app.jwt.signers.sign(payload)
        var headers = HTTPHeaders()
        headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        try app.test(.POST, adminPath, headers: authHeaders, beforeRequest: { req in
            try req.content.encode(gameCreation)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }
    
    func testNonExistentStationEdit() throws {
        let stations = try Station.query(on: app.db).all().wait()
        let gameCreation = try GameCreation(origin_id: stations[0].id!, destination_id: stations[1].id!)
        let payload = try Payload(with: user)
        let accessToken = try app.jwt.signers.sign(payload)
        var headers = HTTPHeaders()
        headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        
        try app.test(.POST, adminPath, headers: authHeaders, beforeRequest: { req in
            try req.content.encode(gameCreation)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            try XCTAssertContent(GameAdminResponse.self, res) { game in
                XCTAssertEqual(game.status, .preparing)
                XCTAssertTrue(try! NSRegularExpression(pattern: "[0-9]{8}").matches(game.pin))
                XCTAssertEqual(game.origin_id, stations[0].id!)
                XCTAssertEqual(game.destination_id, stations[1].id!)
                let station = try Station.query(on: app.db).first().wait()!
                
                let gameEdit = try GameEdit(game_id: game.id!, origin_id: station.id!, destination_id: UUID())
                
                try app.test(.PATCH, adminPath, headers: authHeaders, beforeRequest: { req in
                    try req.content.encode(gameEdit)
                }, afterResponse: { res in
                    XCTAssertEqual(res.status, .notFound)
                    
                })
            }
            
        })
    }
    
    func testIlligalView() throws {
        let stations = try Station.query(on: app.db).all().wait()
        let gameCreation = try GameCreation(origin_id: stations[0].id!, destination_id: stations[1].id!)
        let payload = try Payload(with: user)
        let accessToken = try app.jwt.signers.sign(payload)
        var headers = HTTPHeaders()
        headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        
        try app.test(.POST, adminPath, headers: authHeaders, beforeRequest: { req in
            try req.content.encode(gameCreation)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            try XCTAssertContent(GameAdminResponse.self, res) { game in
                XCTAssertEqual(game.status, .preparing)
                XCTAssertTrue(try! NSRegularExpression(pattern: "[0-9]{8}").matches(game.pin))
                XCTAssertEqual(game.origin_id, stations[0].id!)
                XCTAssertEqual(game.destination_id, stations[1].id!)
                let stations = try Station.query(on: app.db).all().wait()
                
                let hacker = User(fullName: "Hacker User", email: "hacker@hacker.com", passwordHash: "123", isAdmin: true)
                try hacker.save(on: self.app.db).wait()
                let gameUUID = GameUUID(game_id: game.id!)
                try app.test(.GET, adminPath, headers: self.getHeadersByUser(hacker), beforeRequest: { req in
                    try req.content.encode(gameUUID)
                }, afterResponse: { res in
                    XCTAssertEqual(res.status, .forbidden)
                    
                })
            }
            
        })
    }
    
    
    func testIlligal() throws {
        let stations = try Station.query(on: app.db).all().wait()
        let gameCreation = try GameCreation(origin_id: stations[0].id!, destination_id: stations[1].id!)
        let payload = try Payload(with: user)
        let accessToken = try app.jwt.signers.sign(payload)
        var headers = HTTPHeaders()
        headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        
        try app.test(.POST, adminPath, headers: authHeaders, beforeRequest: { req in
            try req.content.encode(gameCreation)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            try XCTAssertContent(GameAdminResponse.self, res) { game in
                XCTAssertEqual(game.status, .preparing)
                XCTAssertTrue(try! NSRegularExpression(pattern: "[0-9]{8}").matches(game.pin))
                XCTAssertEqual(game.origin_id, stations[0].id!)
                XCTAssertEqual(game.destination_id, stations[1].id!)
                let stations = try Station.query(on: app.db).all().wait()
                
                let hacker = User(fullName: "Hacker User", email: "hacker@hacker.com", passwordHash: "123", isAdmin: true)
                try hacker.save(on: self.app.db).wait()
                let gameUUID = GameUUID(game_id: game.id!)
                try app.test(.GET, adminPath, headers: self.getHeadersByUser(hacker), beforeRequest: { req in
                    try req.content.encode(gameUUID)
                }, afterResponse: { res in
                    XCTAssertEqual(res.status, .forbidden)
                    
                })
                
                let gameEdit = try GameEdit(game_id: game.id!, origin_id: stations[1].id!, destination_id: stations[0].id!)
                
                try app.test(.PATCH, adminPath, headers: self.getHeadersByUser(hacker), beforeRequest: { req in
                    try req.content.encode(gameEdit)
                }, afterResponse: { res in
                    XCTAssertEqual(res.status, .forbidden)
                    
                })
                
                
                try app.test(.POST, "\(adminPath)/toggle_status", headers: self.getHeadersByUser(hacker), beforeRequest: { req in
                    try req.content.encode(gameUUID)
                }, afterResponse: { res in
                    XCTAssertEqual(res.status, .forbidden)
                    
                })
            }
            
        })
    }
    
    func testToggle() throws {
        let stations = try Station.query(on: app.db).all().wait()
        let gameCreation = try GameCreation(origin_id: stations[0].id!, destination_id: stations[1].id!)
        let payload = try Payload(with: user)
        let accessToken = try app.jwt.signers.sign(payload)
        var headers = HTTPHeaders()
        headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        
        try app.test(.POST, adminPath, headers: authHeaders, beforeRequest: { req in
            try req.content.encode(gameCreation)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            try XCTAssertContent(GameAdminResponse.self, res) { game in
                XCTAssertEqual(game.status, .preparing)
                XCTAssertTrue(try! NSRegularExpression(pattern: "[0-9]{8}").matches(game.pin))
                XCTAssertEqual(game.origin_id, stations[0].id!)
                XCTAssertEqual(game.destination_id, stations[1].id!)
                let gameUUID = GameUUID(game_id: game.id!)

                try app.test(.POST, "\(adminPath)/toggle_status", headers: authHeaders, beforeRequest: { req in
                    try req.content.encode(gameUUID)
                }, afterResponse: { res in
                    XCTAssertEqual(res.status, .ok)
                    try XCTAssertContent(GameStatusResponse.self, res) { gameStatus in
                        XCTAssertEqual(gameStatus.status, .lobby)
                        try app.test(.POST, "\(adminPath)/toggle_status", headers: authHeaders, beforeRequest: { req in
                            try req.content.encode(gameUUID)
                        }, afterResponse: { res in
                            XCTAssertEqual(res.status, .ok)
                            try XCTAssertContent(GameStatusResponse.self, res) { gameStatus in
                                XCTAssertEqual(gameStatus.status, .in_process)
                                try app.test(.POST, "\(adminPath)/toggle_status", headers: authHeaders, beforeRequest: { req in
                                    try req.content.encode(gameUUID)
                                }, afterResponse: { res in
                                    XCTAssertEqual(res.status, .ok)
                                    try XCTAssertContent(GameStatusResponse.self, res) { gameStatus in
                                        XCTAssertEqual(gameStatus.status, .end)
                                        try app.test(.POST, "\(adminPath)/toggle_status", headers: authHeaders, beforeRequest: { req in
                                            try req.content.encode(gameUUID)
                                        }, afterResponse: { res in
                                            XCTAssertEqual(res.status, .ok)
                                            try XCTAssertContent(GameStatusResponse.self, res) { gameStatus in
                                                XCTAssertEqual(gameStatus.status, .in_process)
                                            }
                                        })
                                    }
                                })
                            }
                        })
                    }
                })
            }
            
        })
    }
    
}
