import Vapor

func migrations(_ app: Application) throws {
    // Initial Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateRefreshToken())
    app.migrations.add(CreateEmailToken())
    app.migrations.add(CreatePasswordToken())
    app.migrations.add(CreateStationsAndStages())
    app.migrations.add(CreateQuestion())
    app.migrations.add(AddQuestionType())
    app.migrations.add(AddQuestionAuthor())
}
