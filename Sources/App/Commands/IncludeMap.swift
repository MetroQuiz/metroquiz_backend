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
    
    func run(using context: CommandContext, signature: Signature) throws {
        let path = context.application.directory.workingDirectory + signature.map_file
        print("📰 Reading map from \(path) file...")
        do {
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            if let data = contents.data(using: .utf8) {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String:AnyObject]
                    
                    context.console.print("❌ Remove old map...")
                    try Station.query(on: context.application.db).delete().flatMap {
                        Stage.query(on: context.application.db).delete()
                    }.flatMap { _ -> EventLoopFuture<Void> in
                        context.console.print("⚙️ Creating stations...")
                        var stages = [String:[(type: StageType, to: String)]]()
                        var stations = [EventLoopFuture<Void>]()
                        if let keys = json?.keys {
                            for key in keys {
                                if let station = json?[key] as? [String:AnyObject] {
                                    if let name = station["name"] as? String,
                                       let color = station["color"] as? String,
                                       let neighbours = station["neighbours"] as? [String:[String]] {
                                        if let changes = neighbours["Change"]
                                        {
                                            if (stages[key] == nil) {
                                                stages[key] = []
                                            }
                                            for change in changes {
                                                stages[key]?.append((type: StageType.change, to: change))
                                            }
                                        }
                                        if let spans = neighbours["Span"]
                                        {
                                            if (stages[key] == nil) {
                                                stages[key] = []
                                            }
                                            for span in spans {
                                                stages[key]?.append((type: StageType.span, to: span))
                                            }
                                        }
                                        if let grounds = neighbours["Ground_change"]
                                        {
                                            if (stages[key] == nil) {
                                                stages[key] = []
                                            }
                                            for ground in grounds {
                                                stages[key]?.append((type: StageType.ground_change, to: ground))
                                            }
                                        }
                                        
                                        stations.append(Station(name: name, line_color: color, svg_id: key).create(on: context.application.db))
                                        
                                    }
                                }
                            }
                        }
                        return stations.flatten(on: context.application.eventLoopGroup.next()).flatMap { _ -> EventLoopFuture<Void> in
                            context.console.print("⚙️ Creating stages...")
                            var stages_result = [EventLoopFuture<Void>]()
                            for (origin_svg_id, destinations_data) in stages {
                                for destination_data in destinations_data {
                                    stages_result.append(
                                        [Station.query(on: context.application.db).filter(\.$svg_id == origin_svg_id).first().unwrap(or: Abort(.notFound)),
                                         Station.query(on: context.application.db).filter(\.$svg_id == destination_data.to).first().unwrap(or: Abort(.notFound))]
                                            .flatten(on: context.application.eventLoopGroup.next())
                                            .flatMap { stations -> EventLoopFuture<Void> in
                                                var origin_station = stations[0]
                                                var destination_station = stations[1]
                                                if (origin_station.svg_id != origin_svg_id) {
                                                    swap(&origin_station, &destination_station)
                                                }
                                                if let origin_id = origin_station.id,
                                                   let destination_id = destination_station.id {

                                                    return Stage(origin_id: origin_id, destination_id: destination_id, stage_type: destination_data.type).create(on: context.application.db)
                                                }
                                                else {
                                                    context.console.print("Ooopps! Stations isn't exists")
                                                    return context.application.eventLoopGroup.next().makeFailedFuture(Abort(.notFound))
                                                }
                                            })
                                }
                            }
                            return stages_result.flatten(on: context.application.eventLoopGroup.next())
                        }
                    }.wait()
                    
                    
                } catch {
                    context.console.print("Something went wrong")
                }
            }
        }
        catch let error as NSError {
            context.console.print("Ooops! Something went wrong: \(error)")
        }
    }
}

