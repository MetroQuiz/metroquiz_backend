//
//  File.swift
//
//
//  Created by Ulyana Eskova on 20.02.2021.
//

import Vapor
import Fluent
import Foundation
import AsyncKit

struct IncludeMap: Command {
    struct Signature: CommandSignature {
        @Argument(name: "map_file")
        var map_file: String
    }
    
    var help: String {
        "Command to include map"
    }
    
    
    static func run(application: Application, map_file: String, print_callback: @escaping (String) -> Void) throws {
        let path = application.directory.workingDirectory + map_file
        print_callback("📰 Reading map from \(path) file...")
        do {
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            if let data = contents.data(using: .utf8) {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String:AnyObject]
                    
                    print_callback("❌ Remove old map...")
                    try Station.query(on: application.db).delete().flatMap {
                        Stage.query(on: application.db).delete()
                    }.flatMap { _ -> EventLoopFuture<Void> in
                        print_callback("⚙️ Creating stations...")
                        var stages = [String:[(type: StageType, to: String)]]()
                        var stations = [EventLoopFuture<Void>]()
                        if let keys = json?.keys {
                            for key in keys {
                                if let station = json?[key] as? [String:AnyObject] {
                                    if let name = station["name"] as? String,
                                       let color = station["color"] as? String,
                                       let neighbours = station["neighbours"] as? [String:[String]] {
                                        if let changes = neighbours["change"]
                                        {
                                            if (stages[key] == nil) {
                                                stages[key] = []
                                            }
                                            for change in changes {
                                                stages[key]?.append((type: StageType.change, to: change))
                                            }
                                        }
                                        if let spans = neighbours["span"]
                                        {
                                            if (stages[key] == nil) {
                                                stages[key] = []
                                            }
                                            for span in spans {
                                                stages[key]?.append((type: StageType.span, to: span))
                                            }
                                        }
                                        if let grounds = neighbours["ground_change"]
                                        {
                                            if (stages[key] == nil) {
                                                stages[key] = []
                                            }
                                            for ground in grounds {
                                                stages[key]?.append((type: StageType.ground_change, to: ground))
                                            }
                                        }
                                        
                                        stations.append(Station(name: name, line_color: color, svg_id: key).create(on: application.db))
                                        
                                    }
                                }
                            }
                        }
                        return stations.flatten(on: application.eventLoopGroup.next()).flatMap { _ -> EventLoopFuture<Void> in
                            print_callback("⚙️ Creating stages...")
                            var stages_result = [EventLoopFuture<Void>]()
                            for (origin_svg_id, destinations_data) in stages {
                                for destination_data in destinations_data {
                                    stages_result.append(
                                        [Station.query(on: application.db).filter(\.$svg_id == origin_svg_id).first().unwrap(or: Abort(.notFound)),
                                         Station.query(on: application.db).filter(\.$svg_id == destination_data.to).first().unwrap(or: Abort(.notFound))]
                                            .flatten(on: application.eventLoopGroup.next())
                                            .flatMap { stations -> EventLoopFuture<Void> in
                                                var origin_station = stations[0]
                                                var destination_station = stations[1]
                                                if (origin_station.svg_id != origin_svg_id) {
                                                    swap(&origin_station, &destination_station)
                                                }
                                                if let origin_id = origin_station.id,
                                                   let destination_id = destination_station.id {

                                                    return Stage(origin_id: origin_id, destination_id: destination_id, stage_type: destination_data.type).create(on: application.db)
                                                }
                                                else {
                                                    print_callback("Ooopps! Stations isn't exists")
                                                    return application.eventLoopGroup.next().makeFailedFuture(Abort(.notFound))
                                                }
                                            })
                                }
                            }
                            return stages_result.flatten(on: application.eventLoopGroup.next())
                        }
                    }.wait()
                    
                    
                } catch {
                    print_callback("Something went wrong")
                }
            }
        }
        catch let error as NSError {
            print_callback("Ooops! Something went wrong: \(error)")
        }
    }
    func run(using context: CommandContext, signature: Signature) throws {
        try IncludeMap.run(application: context.application, map_file: signature.map_file) { text in
            context.console.print(text)
        }
    }
}

