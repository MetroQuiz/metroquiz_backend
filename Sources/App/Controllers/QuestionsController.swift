import Vapor
import Fluent


struct QuestionsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.group(UserAuthenticator()) { authenticated in
        }
    }
}
