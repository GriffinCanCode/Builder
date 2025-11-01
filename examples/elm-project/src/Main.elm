module Main exposing (main)

import Browser
import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)


-- MAIN


main : Program () Model Msg
main =
    Browser.sandbox
        { init = init
        , update = update
        , view = view
        }


-- MODEL


type alias Model =
    { count : Int
    }


init : Model
init =
    { count = 0
    }


-- UPDATE


type Msg
    = Increment
    | Decrement
    | Reset


update : Msg -> Model -> Model
update msg model =
    case msg of
        Increment ->
            { model | count = model.count + 1 }

        Decrement ->
            { model | count = model.count - 1 }

        Reset ->
            { model | count = 0 }


-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ div [] [ text ("Count: " ++ String.fromInt model.count) ]
        , button [ onClick Increment ] [ text "+" ]
        , button [ onClick Decrement ] [ text "-" ]
        , button [ onClick Reset ] [ text "Reset" ]
        ]

