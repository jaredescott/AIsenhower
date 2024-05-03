"""
A simple Eisenhower matrix display for Reclaim.ai users.

This code fetches tasks from the Reclaim.ai API and organizes them into an Eisenhower matrix, which categorizes tasks based on their urgency and importance. The matrix is displayed using a graphical user interface.

Author: Jared Scott
License: MIT
"""

# User-defined settings
const API_KEY = "<my_api_key>" # Replace with your own API key from https://app.reclaim.ai/settings/developer
const DARK_MODE = true


const API_URL = "https://api.app.reclaim.ai/api/tasks?status=NEW%2CSCHEDULED%2CIN_PROGRESS%2CCOMPLETE&instances=true"
const VIEWPORT_HEIGHT_RATIO = 25/4
const LABEL_WIDTH = 51
const DEPENDENCIES = [
    "HTTP",
    "JSON",
    "LiveServer"
]

using Pkg
const installed_packages = Pkg.installed()
is_installed(pkg::String) = haskey(installed_packages, pkg)

function input(prompt::String)
    print(prompt)
    return readline()
end

@info "Loading dependencies..."

if !is_installed("Mousetrap")
    Pkg.add(url="https://github.com/clemapfel/mousetrap.jl")
    Pkg.test("Mousetrap")
end

for dependency in DEPENDENCIES
    if !is_installed(dependency)
        Pkg.add(dependency)
    end
end

using Mousetrap, HTTP
using JSON: parse
using LiveServer: open_in_default_browser

function get_tasks(url::String, token::String, _anonymous::Bool=false)
    @info "Fetching tasks..."

    headers = [
        "Authorization" => "Bearer $token",
        "Content-Type" => "application/json",
        "Accept" => "application/json"
    ]

    response = HTTP.get(url, headers)
    tasks = parse(String(response.body))

    if _anonymous
        i = 0
        for task in tasks
            task["title"] = " "^40 * "Task $(i += 1)" * " "^40
        end
    end

    # @info "Tasks fetched."
    return tasks
end

function reversed_dict(d::Dict)
    return Dict(v => k for (k, v) in d)
end

const priority_to_action = Dict(
    "P1" => :DO,
    "P2" => :DECIDE,
    "P3" => :DELEGATE,
    "P4" => :DELETE
)
const action_to_priority = reversed_dict(priority_to_action)

function partition_tasks(tasks)
    @info "Organizing tasks..."
    task_matrix = Dict{Symbol, Array{Dict{String, Any}, 1}}(
        :DO => [],
        :DECIDE => [],
        :DELEGATE => [],
        :DELETE => []
    )

    for task in tasks
        priority = task["priority"]
        # priority = task["onDeck"] ? "P1" : task["priority"] # Uncomment to prioritize "on deck" tasks
        push!(task_matrix[priority_to_action[priority]], task)
    end

    return task_matrix
end

struct Tags
    bold::String
    italic::String
    underline::String
    monospace::String
    small::String
end
const tags = Tags("b", "i", "u", "tt", "small")

struct TextFormat
    tag::Function
    bold::Function
    italic::Function
    underline::Function
    monospace::Function
    small::Function
    parenthesize::Function
    color::Function
    untag::Function
    pad::Function
end
const format = TextFormat(
    (text::String, tag::String) -> "<$tag>$text</$tag>",
    (text::String) -> format.tag(text, tags.bold),
    (text::String) -> format.tag(text, tags.italic),
    (text::String) -> format.tag(text, tags.underline),
    (text::String) -> format.tag(text, tags.monospace),
    (text::String) -> format.tag(text, tags.small),
    (text::String) -> "($text)",
    (text::String, color::String) -> "<span color='$color'>$text</span>",
    (tag::String) -> if tag[2] == "/" replace(tag, "/" => "") else replace(tag, "<" => "</") end,
    (text::String, target_length::Int) -> "$(repeat(" ", round((target_length - length(text))/2)))$text$(repeat(" ", round((target_length - length(text))/2)))"
)


function generate_child(label::String)
    matrix = Frame(Overlay(Separator(), Label(label)))
    set_margin!(matrix, 3)
    return matrix
end

function create_tasks_box(label, tasks)
    matrix = Box(ORIENTATION_VERTICAL)
    set_expand!(matrix, true)
    # title_widget = Label(format.pad((String(label)), LABEL_WIDTH) |> format.bold |> format.underline)
    title_widget = Label("\n$(String(label) |> format.bold)\n")
    push_back!(matrix, title_widget)
    push_back!(matrix, Separator())
    for task in tasks
        task_button = Button(Label(task["onDeck"] ? (format.color(task["title"], "green")) : task["title"]))
        connect_signal_clicked!(task_button) do x::Button
            open_in_default_browser("https://app.reclaim.ai/tasks/$(task["id"])")
            nothing
        end
        push_back!(matrix, task_button)
    end
    return matrix
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
    set_expand!(s, true)
    set_expand!(tasks_box, true)
    o = Overlay(s, tasks_box)
    set_expand!(o, true)
    return o
end

function eisenhower_label(text::String, opacity::Float64=0.5)
    label = Label(format.bold(text))
    set_opacity!(label, opacity)
    return label
end

main() do AIsenhower::Application
    # set theme
    DARK_MODE && set_current_theme!(AIsenhower, THEME_DEFAULT_DARK)

    window = Window(AIsenhower)
    set_expand!(window, true)
    set_title!(window, "AIsenhower")

    api_key = API_KEY == "<my_api_key>" ? input("Please enter your API key: ") : API_KEY
    tasks = get_tasks(API_URL, api_key, true)[1:30]
    task_matrix = partition_tasks(tasks)
    sublabel_format = (text::String) -> text |> format.parenthesize |> format.italic

    @info "Preparing Eisenhower matrix..."

    # create column view
    matrix = ColumnView()
    set_expand!(matrix, true)
    column = push_back_column!(matrix, " ") # empty column

    viewports = Dict(
        :DO => Viewport(),
        :DECIDE => Viewport(),
        :DELEGATE => Viewport(),
        :DELETE => Viewport()
    )
    set_expand!.(values(viewports), true)
    min_height = maximum(length.(t["title"] for t in tasks)) * VIEWPORT_HEIGHT_RATIO
    println(min_height)
    for viewport in values(viewports)
        set_size_request!(viewport, Vector2f(0, min_height/2))
    end
    
    function set_children()
        set_child!(viewports[:DO], format_tasks_box(create_tasks_box("DO $(action_to_priority[:DO] |> sublabel_format)", task_matrix[:DO]), "success"))
        set_child!(viewports[:DECIDE], format_tasks_box(create_tasks_box("DECIDE $(action_to_priority[:DECIDE] |> sublabel_format)", task_matrix[:DECIDE]), "warning"))
        set_child!(viewports[:DELEGATE], format_tasks_box(create_tasks_box("DELEGATE $(action_to_priority[:DELEGATE] |> sublabel_format)", task_matrix[:DELEGATE]), "accent"))
        set_child!(viewports[:DELETE], format_tasks_box(create_tasks_box("DELETE $(action_to_priority[:DELETE] |> sublabel_format)", task_matrix[:DELETE]), "error"))
    end

    set_children()

    # column 1: Important/Less Important
    column = push_back_column!(matrix, " ")
    important_label = eisenhower_label("Important")
    set_widget_at!(matrix, column, 2, important_label)
    unimportant_label = eisenhower_label("Less Important")
    set_widget_at!(matrix, column, 3, unimportant_label)

    # column 2: Urgent
    column = push_back_column!(matrix, " ")
    urgent_label = eisenhower_label("Urgent")
    set_widget_at!(matrix, column, 1, urgent_label)
    set_widget_at!(matrix, column, 2, viewports[:DO])
    set_widget_at!(matrix, column, 3, viewports[:DELEGATE])
    
    # column 3: Not Urgent
    column = push_back_column!(matrix, " ")
    not_urgent_label = eisenhower_label("Not Urgent")
    set_widget_at!(matrix, column, 1, not_urgent_label)
    set_widget_at!(matrix, column, 2, viewports[:DECIDE])
    set_widget_at!(matrix, column, 3, viewports[:DELETE])

    # refresh button
    column = push_back_column!(matrix, " ")
    refresh_button = Button(Label("&#8635;"))
    set_opacity!(refresh_button, 0.5)
    connect_signal_clicked!(refresh_button) do x::Button
        @info "Refreshing..."
        task_matrix = partition_tasks(get_tasks(API_URL, api_key))
        set_children()
        @info "Tasks reloaded."
    end
    set_widget_at!(matrix, column, 4, refresh_button)

    set_propagate_natural_width!.(values(viewports), true)

    set_child!(window, matrix)
    
    @info "Displaying Eisenhower matrix..."
    present!(window)
end

