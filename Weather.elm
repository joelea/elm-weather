module Weather exposing (..)

import Config
import Html exposing (..)
import Html.Attributes exposing (style, value, type', src)
import Html.Events exposing (onClick, onInput, on, keyCode)
import Http
import Json.Decode as Json
import Task
import String


-- MODEL


type alias Model =
    { cities : List City
    , nameInput : String
    , nextId : Id
    }


type alias City =
    { id : Id
    , name : String
    , temp : Maybe.Maybe Int
    , loadingState : LoadingState
    }


type alias Id =
    Int


type LoadingState
    = Progress
    | Completed


init : ( Model, Cmd Msg )
init =
    ( initialModel, updateAllCmd initialModel )


initialModel : Model
initialModel =
    { cities = initialCities
    , nameInput = ""
    , nextId = List.length initialCities + 1
    }


initialCities : List City
initialCities =
    [ "Alaska", "Berlin", "Chicago", "Düsseldorf", "Istanbul", "Madrid", "Munich", "New York" ]
        |> List.indexedMap (\i e -> City (i + 1) e Nothing Progress)


updateAllCmd : Model -> Cmd Msg
updateAllCmd model =
    Cmd.batch (List.map getUpdatedTemp model.cities)


createCity : Id -> String -> City
createCity id name =
    City id name Nothing Progress



-- UPDATE


type Msg
    = NoOp
    | UpdateNameField String
    | AddCity
    | DeleteCity Id
    | RequestTempUpdate City
    | RequestTempUpdateAll
    | UpdateTemp Id Float
    | UpdateTempFail Http.Error
    | SortByCity


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        UpdateNameField input ->
            ( { model | nameInput = input }, Cmd.none )

        AddCity ->
            let
                newCity =
                    City model.nextId model.nameInput Nothing Progress
            in
                if String.isEmpty model.nameInput then
                    (model ! [])
                else
                    ( { model
                        | nameInput = ""
                        , cities = model.cities ++ [ newCity ]
                        , nextId = model.nextId + 1
                      }
                    , getUpdatedTemp newCity
                    )

        DeleteCity id ->
            let
                citiesDeleted =
                    List.filter (\e -> e.id /= id) model.cities
            in
                ( { model | cities = citiesDeleted }, Cmd.none )

        RequestTempUpdate city ->
            let
                changeCity =
                    \e ->
                        { e
                            | loadingState =
                                if e.id == city.id then
                                    Progress
                                else
                                    e.loadingState
                        }

                updateCities =
                    List.map changeCity model.cities
            in
                ( { model | cities = updateCities }, getUpdatedTemp city )

        UpdateTemp id temp ->
            let
                convertTemp temp =
                    Maybe.Just (round temp)

                changeCity =
                    \e ->
                        { e
                            | loadingState = Completed
                            , temp =
                                if e.id == id then
                                    (convertTemp temp)
                                else
                                    e.temp
                        }

                updatedCity =
                    List.map changeCity model.cities
            in
                ( { model | cities = updatedCity }, Cmd.none )

        UpdateTempFail _ ->
            ( model, Cmd.none )

        RequestTempUpdateAll ->
            let
                setProgress =
                    List.map (\c -> { c | loadingState = Progress }) model.cities
            in
                ( { model | cities = setProgress }, updateAllCmd model )

        SortByCity ->
            let
                sortCities =
                    List.sortBy .name model.cities
            in
                ( { model | cities = sortCities }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div
        []
        [ h1 [] [ text "Cities" ]
        , viewCityForm model
        , viewCities model
        ]


viewCityForm : Model -> Html Msg
viewCityForm model =
    div
        []
        [ label [] [ text "Ctiy: " ]
        , input [ onInput UpdateNameField, value model.nameInput, onEnter AddCity ] []
        , input [ type' "button", value "Add city", onClick AddCity ] []
        , input [ type' "button", value "Update all", onClick RequestTempUpdateAll ] []
        , input [ type' "button", value "Sort by city", onClick SortByCity ] []
        ]


onEnter : Msg -> Attribute Msg
onEnter msg =
    let
        tagger code =
            if code == 13 then
                msg
            else
                NoOp
    in
        on "keydown" (Json.map tagger keyCode)


viewCities : Model -> Html Msg
viewCities model =
    table [] (List.map viewCity model.cities)


viewCity : City -> Html Msg
viewCity city =
    let
        tempToString =
            Maybe.withDefault "..." (Maybe.map toString city.temp)

        cityTemp =
            case city.loadingState of
                Progress ->
                    viewSpinner

                Completed ->
                    text (tempToString ++ "°C")
    in
        tr []
            [ td [ style [ ( "min-width", "2em" ) ] ] [ text (toString city.id) ]
            , td [ style [ ( "min-width", "12em" ) ] ] [ text city.name ]
            , td [ style [ ( "width", "6em" ) ] ] [ cityTemp ]
            , td [] [ button [ onClick (RequestTempUpdate city) ] [ text "Update" ] ]
            , td [] [ button [ onClick (DeleteCity city.id) ] [ text "delete" ] ]
            ]


viewSpinner : Html Msg
viewSpinner =
    img [ src "assets/spinner.gif" ] []



-- EFFECTS


getUpdatedTemp : City -> Cmd Msg
getUpdatedTemp city =
    Http.get decodeData (weatherURL city.name)
        |> Task.perform UpdateTempFail (UpdateTemp city.id)


weatherURL : String -> String
weatherURL cityName =
    Http.url "http://api.openweathermap.org/data/2.5/weather" [ ( "q", cityName ), ( "units", Config.unit ), ( "APPID", Config.apiKey ) ]


decodeData : Json.Decoder Float
decodeData =
    Json.at [ "main", "temp" ] Json.float
