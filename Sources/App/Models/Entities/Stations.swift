//
//  File.swift
//  
//
//  Created by Ulyana Eskova on 20.02.2021.
//

import Vapor
import Fluent

// Stage between two stations, like edge in graph

enum StageType: String, Codable {
    case span
    case change
    case ground_change
}

final class Stage: Model {
    static let schema = "stages"
    
    
    @ID(key: .id)
    var id: UUID?
    
    
    @Parent(key: "origin_id")
    var origin: Station
    
    @Parent(key: "destination_id")
    var destination: Station
    
    @Enum(key: "stage_type")
    var stage_type: StageType
    
    init() {}
    
    init(id: UUID? = nil, origin_id: UUID, destination_id: UUID, stage_type: StageType) {
        self.id = id
        self.$origin.id = origin_id
        self.$destination.id = destination_id
        self.stage_type = stage_type
    }
    
}


final class Station: Model {
    static let schema = "stations"
    
    struct StationResponse : Content {
        let name: String
        let id: UUID
        init(name: String, id: UUID) {
            self.name = name
            self.id = id
        }
    }
    struct StationSVGResponse : Content {
        let svg_id: String
        let id: UUID
        init(svg_id: String, id: UUID) {
            self.svg_id = svg_id
            self.id = id
        }
    }
    
    @ID(key: .id)
    var id: UUID?
    
    @Siblings(through: Stage.self, from: \.$origin, to: \.$destination)
    var neighbours: [Station]
    
    @Children(for: \.$station)
    var questions: [Question]
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "line_color")
    var line_color: String
    
    @Field(key: "svg_id")
    var svg_id: String
    
    init() {}
    
    init(
        id: UUID? = nil,
        name: String,
        line_color: String,
        svg_id: String
    ) {
        self.id = id
        self.name = name
        self.line_color = line_color
        self.svg_id = svg_id
    }
}
