# Metroquiz backend
Backed written for metroqiuz website (https://github.com/MetroQuiz/metroquiz_frontend)
### Routes
| URL                             | HTTP Method | Description                                              | Content (Body)          |
|---------------------------------|:-----------:|----------------------------------------------------------|-------------------------|
| /auth/register                   |     POST    | Registers a user and sends email verification            | `RegisterRequest`       |
| /auth/login                      |     POST    | Login with existing user (requires email verification)   | `LoginRequest`          |
| /auth/me                         |     GET     | Returns the current authenticated user                   | None                    |
| /auth/accessToken                |     POST    | Gives the user a new accesstoken and refresh token       | `AccessTokenRequest`    |
| /admin/me                        |     GET     | Return full information to display on admin panel(games and quesion amount       | `AllGameResponse`    |
| /admin                           |     GET     | Return game description by it UUID                       | `GameAdminResponse`     |
| /admin                           |     PATCH   | Change game and return it description                    | `GameAdminResponse`     |
| /admin                           |     POST    | Create game and return it description                    | `GameAdminResponse`     |
| /admin/toggle_status             |     POST    | Change game status and return new one                    | `GameStatusResponse`    |
| /stations                        |     GET     | Return all stations                                      | `[Station.StationResponse]`|
| /enter                           |     POST    | Register new participant for game and return his tmp token | `EnterResponse`       |
| /game/passed                     |     GET     | Return list of already passed stations                   | `GameInfoResponse`      |
| /game/question_get               |     POST    | Mark stations as passed and return question to answer    | `QuestionResponse`      |
| /game/question                   |     POST    | Check participant answer                                 | `AnswerResponse`        |
| /game/results                    |     GET     | Return results of game                                   | `[String: Int]`<br/>(Name : score)       |
| /question                        | GET/PATCH/ADD/DELETE | Add/change/delete/get question                  | `QuesionResponse`       |
| /question/by_station             | GET         | Return all question for stations                         | `[QuesionResponse]`       |

### Auth tokens
In all routes starting admin or question requires to use bearer token of user, it can be got using `/auth/accessToken` request
In all routes starting game requires to use temporary bearer token of participant, it can be got useing 'enter' request

### Database
Metriquiz backend uses `postgresql` database, it should be configured in .env file using **POSTGRES_HOSTNAME**, **POSTGRES_USERNAME**, **POSTGRES_PASSWORD**, **POSTGRES_DATABASE** varibles
All models are described in `/Sources/App/Models/Entities` files, all their request/response  representations described in `/Sources/App/Models/DTO`

### Websocket
To be aware of game state connect websocket on route `/ws`, after connection it will wait for participant bearer token, after authentication will be passed websocket will notify about game state changing using JSON format

### Jobs
For scheduled jobs metriquiz uses Redis server, it should be configured in .env file. Particularly jobs used for countdown for a question answering

### Game rules and front-end
To read more metroquiz visit front-end repo https://github.com/MetroQuiz/metroquiz_frontend
