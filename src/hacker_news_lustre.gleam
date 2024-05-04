import gleam/dynamic
import gleam/fetch
import gleam/http/request
import gleam/http/response.{type Response, Response}
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/attribute.{style}
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html.{div, h1}

type State {
  State(story_items: Deferred(Result(List(HackerNewsItem), String)))
}

type HackerNewsItem {
  HackerNewsItem(id: Int, title: String, url: Option(String))
}

type Deferred(t) {
  HasNotStartedYet
  InProgress
  Resolved(t)
}

type AsyncOperationStatus(t) {
  Started
  Finished(t)
}

type Msg {
  LoadStoryItems(AsyncOperationStatus(Result(List(HackerNewsItem), String)))
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_flags) -> #(State, Effect(Msg)) {
  let initial_state = State(HasNotStartedYet)
  let initial_effect =
    effect.from(fn(dispatch) { dispatch(LoadStoryItems(Started)) })

  #(initial_state, initial_effect)
}

fn update(_state, msg) -> #(State, Effect(Msg)) {
  case msg {
    LoadStoryItems(Started) -> {
      let next_state = State(story_items: InProgress)
      #(next_state, load_story_items())
    }
    LoadStoryItems(Finished(Ok(story_items))) -> {
      let next_state = State(story_items: Resolved(Ok(story_items)))
      #(next_state, effect.none())
    }
    LoadStoryItems(Finished(Error(err))) -> {
      let next_state = State(story_items: Resolved(Error(err)))
      #(next_state, effect.none())
    }
  }
}

fn view(state: State) {
  div([style([#("padding", "20px")])], [
    h1([], [element.text("Lustre Hackernews")]),
    render_items(state.story_items),
  ])
}

fn render_items(story_items) {
  case story_items {
    HasNotStartedYet -> div([], [])
    InProgress -> spinner()
    Resolved(Error(err)) -> render_error(err)
    Resolved(Ok(items)) -> div([], list.map(items, render_item))
  }
}

fn render_item(item: HackerNewsItem) {
  div([], [
    case item.url {
      Some(url) -> {
        html.a([attribute.src(url), attribute.target("_blank")], [
          element.text(item.title),
        ])
      }
      None -> html.p([], [html.text(item.title)])
    },
  ])
}

fn spinner() {
  div([style([#("textAlign", "center"), #("marginTop", "15")])], [
    element.text("Loading..."),
  ])
}

fn render_error(error_message) {
  h1([style([#("color", "red")])], [element.text(error_message)])
}

const stories_endpoint = "https://hacker-news.firebaseio.com/v0/topstories.json"

fn load_story_items() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    load_item_ids()
    |> promise.try_await(load_items_from_ids)
    |> promise.map(fn(result) { LoadStoryItems(Finished(result)) })
    |> promise.tap(fn(message) { dispatch(message) })

    Nil
  })
}

fn load_item_ids() -> Promise(Result(List(Int), String)) {
  let assert Ok(req) = request.to(stories_endpoint)

  fetch.send(req)
  |> promise.try_await(fetch.read_bytes_body)
  |> promise.map(result.map_error(_, fn(_) { "Fetch Error" }))
  |> promise.try_await(fn(resp) {
    let Response(_, _, body) = resp
    promise.resolve(parse_ids(body))
  })
}

fn parse_ids(body) -> Result(List(Int), _) {
  let decoder = dynamic.list(dynamic.int)
  json.decode_bits(body, decoder)
  |> result.map_error(fn(_) { "Parse Error" })
}

fn load_items_from_ids(
  ids: List(Int),
) -> Promise(Result(List(HackerNewsItem), _)) {
  ids
  |> list.take(10)
  |> list.map(load_story_item)
  |> promise.await_list
  |> promise.map(fn(list) { result.all(list) })
}

fn load_story_item(id) -> Promise(Result(HackerNewsItem, _)) {
  let endpoint =
    "https://hacker-news.firebaseio.com/v0/item/"
    <> int.to_string(id)
    <> ".json"

  let assert Ok(req) = request.to(endpoint)

  fetch.send(req)
  |> promise.try_await(fetch.read_bytes_body)
  |> promise.map(result.map_error(_, fn(_) { "Fetch Error" }))
  |> promise.try_await(fn(resp) {
    let Response(_, _, body) = resp
    body
    |> parse_item
    |> result.map_error(fn(_) { "Parse Error" })
    |> promise.resolve
  })
}

fn parse_item(body) -> Result(HackerNewsItem, _) {
  let decoder =
    dynamic.decode3(
      HackerNewsItem,
      dynamic.field("id", dynamic.int),
      dynamic.field("title", dynamic.string),
      dynamic.optional_field("url", dynamic.string),
    )
  json.decode_bits(body, decoder)
}

@external(javascript, "./sleep.mjs", "sleep")
pub fn sleep(_ms: Int, callback: fn() -> a) -> a {
  callback()
}
