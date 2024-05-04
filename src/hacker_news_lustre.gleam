import gleam/list
import gleam/option.{type Option, None, Some}
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
      #(next_state, effect.from(load_story_items))
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

fn load_story_items(dispatch) {
  use <- sleep(1500)
  let story_items = [HackerNewsItem(id: 1, title: "Example title", url: None)]

  dispatch(LoadStoryItems(Finished(Ok(story_items))))

  Nil
}

@external(javascript, "./sleep.mjs", "sleep")
pub fn sleep(_ms: Int, _callback: fn() -> Nil) -> Nil {
  Nil
}
