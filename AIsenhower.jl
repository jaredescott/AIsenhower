# AIsenhower.jl
# 
# Description: A simple Eisenhower matrix display for Reclaim.ai users

API_KEY = "<my_api_key>" # Replace with your own API key from https://app.reclaim.ai/settings/developer


DISPLAY_WINDOW = true
API_URL = "https://api.app.reclaim.ai/api/tasks?status=NEW%2CSCHEDULED%2CIN_PROGRESS%2CCOMPLETE&instances=true"
VERSION = "0.1.0"

function input(prompt::String)
    print(prompt)
    return readline()
end

install = input("Install dependencies? (y/N): ")

if install in ["y", "Y"]
    using Pkg

    begin
        Pkg.add(url="https://github.com/clemapfel/mousetrap.jl")
        Pkg.test("Mousetrap")
    end

    dependencies = [
        "HTTP",
        "JSON",
        "LiveServer",
        "PyCall"
    ]

    for dep in dependencies
        Pkg.add(dep)
    end
end


using Mousetrap, HTTP, JSON#, PyCall
using LiveServer: open_in_default_browser

if API_KEY == "<my_api_key>"
    API_KEY = input("Please enter your API key: ")
end

headers = [
    "Authorization" => "Bearer $API_KEY",
    "Content-Type" => "application/json",
    "Accept" => "application/json"
]

response = HTTP.get(API_URL, headers)

tasks = JSON.parse(String(response.body))
# println(tasks[1]) # sanity check

task_properties = tasks[1] |> keys
# println(task_properties)

function reversed_dict(d::Dict)
    return Dict(v => k for (k, v) in d)
end

priority_to_action = Dict(
    "P1" => :DO,
    "P2" => :DECIDE,
    "P3" => :DELEGATE,
    "P4" => :DELETE
)
action_to_priority = reversed_dict(priority_to_action)

task_matrix = Dict{Symbol, Array{Dict{String, Any}, 1}}(
    :DO => [],
    :DECIDE => [],
    :DELEGATE => [],
    :DELETE => []
)

for task in tasks
    priority = task["priority"]
    priority = task["onDeck"] ? "P1" : task["priority"]
    push!(task_matrix[priority_to_action[priority]], task)
end

# println(task_matrix) # sanity check

bold = (text::String) -> "<b>$text</b>"
italic = (text::String) -> "<i>$text</i>"
underline = (text::String) -> "<u>$text</u>"
big = (text::String) -> "<big>$text</big>"
on_deck_font = (text::String) -> "<span color='green'>$text</span>" |> italic
function antitag(tag::String)
    if tag[2] == "/"
        return replace(tag, "/" => "")
    else
        return replace(tag, "<" => "</")
    end
end
# function normal(text::String)
#     for tag in ["<b>", "</b>", "<i>", "</i>", "<u>", "</u>"]
#         text = replace(text, tag => antitag(tag))
#     end
# end
parenthesize = (text::String) -> "($text)"

function generate_child(label::String)
    out = Frame(Overlay(Separator(), Label(label)))
    set_margin!(out, 3)
    return out
end

function create_tasks_box(label, tasks)
    out = Box(ORIENTATION_VERTICAL)
    title_widget = Label(bold(String(label)))
    push_back!(out, title_widget)
    for task in tasks
        task_button = Button(Label(task["onDeck"] ? on_deck_font(task["title"]) : task["title"]))
        connect_signal_clicked!(task_button) do x::Button
            open_in_default_browser("https://app.reclaim.ai/tasks/$(task["id"])")
            nothing
        end
        push_back!(out, task_button)
    end
    return out
    # c = ColumnView()
    # c1 = push_back_column!(c, String(label))
    # set_widget_at!(c, c1, 1, out)
    # return c
end

function add_css_classes!(widget, classes...)
    for class in classes
        add_css_class!(widget, class)
    end
end

function format_tasks_box(tasks_box, color=nothing)
    s = Separator()
    if color !== nothing
        add_css_class!(s, color)
    end
    return Overlay(s, tasks_box)
end

function create_eisenhower_matrix(task_matrix)
    out = Paned(ORIENTATION_HORIZONTAL)
    out1, out2 = Paned(ORIENTATION_VERTICAL), Paned(ORIENTATION_VERTICAL)
    sublabel_format = (text::String) -> text |> parenthesize |> italic
    set_start_child!(out1, format_tasks_box(create_tasks_box("DO $(      action_to_priority[:DO] |>       sublabel_format)", task_matrix[:DO]),       "success"))
    set_start_child!(out2, format_tasks_box(create_tasks_box("DECIDE $(  action_to_priority[:DECIDE] |>   sublabel_format)", task_matrix[:DECIDE]),   "warning"))
    set_end_child!(  out1, format_tasks_box(create_tasks_box("DELEGATE $(action_to_priority[:DELEGATE] |> sublabel_format)", task_matrix[:DELEGATE]), "accent"))
    set_end_child!(  out2, format_tasks_box(create_tasks_box("DELETE $(  action_to_priority[:DELETE] |>   sublabel_format)", task_matrix[:DELETE]),   "error"))
    set_start_child!(out,  out1)
    set_end_child!(  out,  out2)
    return out
end

if DISPLAY_WINDOW
    main() do app::Application
        window = Window(app)
        set_title!(window, "AIsenhower v$VERSION")

        eisenhower_matrix = create_eisenhower_matrix(task_matrix)
        set_child!(window, eisenhower_matrix)
        present!(window)
    end
end
