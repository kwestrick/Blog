library(shiny)
library(shinyjs)
library(readr)
library(dplyr)
library(stringr)
library(DT)

# Detect environment: TRUE when running locally, FALSE when deployed to Connect Cloud
is_local    <- file.exists("../docs/blog_registry.csv")
registry_path <- if (is_local) "../docs/blog_registry.csv" else "blog_registry.csv"
blog_root   <- normalizePath(file.path(dirname(registry_path), ".."), mustWork = FALSE)

# Credentials — only used in cloud deployment
credentials <- list(
  admin = "grunt11B!",
  ken   = "ken321Neth!",
  anton = "an321Ton!"
)

check_login <- function(user, password) {
  isTRUE(credentials[[user]] == password)
}

# ── Helpers ──────────────────────────────────────────────────────────────────

slugify <- function(title) {
  title %>%
    str_to_lower() %>%
    str_replace_all("[_ ]", "-") %>%
    str_remove_all("[^a-z0-9-]")
}

generate_post_id <- function(existing_ids) {
  numeric_ids <- suppressWarnings(as.integer(existing_ids))
  max_id <- max(numeric_ids, 0L, na.rm = TRUE)
  as.character(seq(max_id + 1, length.out = length(existing_ids)))
}

read_blog_registry <- function(path = registry_path) {
  df <- read_csv(path, show_col_types = FALSE) %>%
    mutate(
      draft_started  = as.Date(draft_started),
      published_date = as.Date(published_date),
      post_id        = as.character(post_id),
      post_id        = coalesce(post_id, ""),
      title          = coalesce(title, ""),
      lead_quote     = coalesce(lead_quote, ""),
      gist           = coalesce(gist, ""),
      publication    = str_trim(tolower(coalesce(publication, ""))),
      status         = str_trim(tolower(coalesce(status, ""))),
      path           = coalesce(path, ""),
      chart_path     = coalesce(chart_path, ""),
      image_path     = coalesce(image_path, ""),
      notes          = coalesce(notes, ""),
      tags           = coalesce(tags, "")
    ) %>%
    mutate(
      publication = if_else(publication == "", "unassigned", publication),
      status      = if_else(status == "", "unassigned", status)
    )

  missing_ids <- which(df$post_id == "" | is.na(df$post_id))
  if (length(missing_ids) > 0) {
    df$post_id[missing_ids] <- generate_post_id(df$post_id[-missing_ids])
    write_csv(df, path, na = "")
  }

  df
}

write_blog_registry <- function(df, path = registry_path) {
  write_csv(df, path, na = "")
}

# ── UI ────────────────────────────────────────────────────────────────────────

login_ui <- fluidPage(
  tags$div(
    style = "max-width: 360px; margin: 120px auto; padding: 32px; border: 1px solid #ddd; border-radius: 8px; background: #fafafa;",
    h3("Blog Dashboard", style = "text-align: center; margin-bottom: 24px;"),
    textInput("login_user", "Username", width = "100%"),
    passwordInput("login_pass", "Password", width = "100%"),
    actionButton("login_btn", "Sign in", class = "btn-primary", width = "100%"),
    br(), br(),
    textOutput("login_error")
  )
)

main_ui <- fluidPage(
  shinyjs::useShinyjs(),
  tags$head(
    tags$script(HTML("
      $(document).on('change', '.status-select, .publication-select', function() {
        var postId = $(this).data('post-id');
        var field = $(this).hasClass('status-select') ? 'status' : 'publication';
        var value = $(this).val();
        if (field === 'status') {
          var statusColorMap = {unassigned: 'red', published: 'green'};
          $(this).css('color', statusColorMap[value] || 'blue');
        }
        if (field === 'publication') {
          $(this).css('color', value === 'unassigned' ? 'red' : 'black');
        }
        Shiny.setInputValue('update_cell_click', {
          id: postId,
          field: field,
          value: value,
          time: Date.now()
        });
      });
    "))
  ),
  titlePanel("Ken's Blog Workflow Dashboard"),

  sidebarLayout(
    sidebarPanel(
      actionButton("refresh", "Refresh data"),
      br(), br(),

      # Local: new post scaffolding
      if (is_local) tagList(
        textInput("new_post_title", "New post title"),
        actionButton("scaffold_post", "Create new post"),
        textOutput("scaffold_status"),
        br(), br(),
        actionButton("upload_to_cloud", "↑ Upload to Cloud", class = "btn-success", width = "100%"),
        br(),
        textOutput("upload_status"),
        br(), br()
      ),

      # Cloud: CSV download + sign out + note
      if (!is_local) tagList(
        downloadButton("download_csv", "Download registry CSV"),
        br(), br(),
        actionButton("sign_out", "Sign out", class = "btn-danger", width = "100%"),
        hr(),
        tags$div(
          style = "padding: 10px; background-color: #fff3cd; border-radius: 4px; margin-bottom: 15px;",
          tags$strong("Note:"), " New posts must be created locally using ",
          tags$code("./new_post.sh"), " or the local Shiny app."
        ),
        br()
      ),

      selectInput("status_filter", "Status", choices = NULL, multiple = TRUE),
      selectInput("publication_filter", "Publication", choices = NULL, multiple = TRUE),
      textInput("search_text", "Search title / gist / tags", value = ""),
      checkboxInput("missing_only", "Show only posts missing key metadata", value = FALSE),

      width = 2
    ),

    mainPanel(
      fluidRow(
        column(3, wellPanel(h4("Total posts"),    textOutput("total_posts"))),
        column(3, wellPanel(h4("Published"),       textOutput("published_posts"))),
        column(3, wellPanel(h4("Unpublished"),     textOutput("unpublished_posts"))),
        column(3, wellPanel(h4("Missing fields"),  textOutput("missing_posts")))
      ),

      tabsetPanel(
        id = "main_tabs",

        tabPanel(
          "Posts",
          br(),
          DTOutput("posts_table")
        ),

        tabPanel(
          uiOutput("edit_tab_title"),
          value = "edit_tab",
          br(),
          actionButton("back_to_posts", "← Back to Posts"),
          br(), br(),
          verbatimTextOutput("selected_post_id"),

          textInput("edit_title", "Title", width = "100%"),
          textAreaInput("edit_lead_quote", "Lead quote", rows = 3, width = "100%"),
          textAreaInput("edit_gist", "Gist", rows = 4, width = "100%"),

          fluidRow(
            column(6, dateInput("edit_draft_started",  "Draft started")),
            column(6, dateInput("edit_published_date", "Published date"))
          ),

          fluidRow(
            column(6, selectInput("edit_status", "Status",
              choices = c("idea", "drafting", "editing", "scheduled", "published", "unassigned"))),
            column(6, selectInput("edit_publication", "Publication",
              choices = c("unassigned", "substack", "website", "both")))
          ),

          textInput("edit_path",       "Path", width = "100%"),
          textInput("edit_chart_path", "Chart / graph / map / table path", width = "100%"),
          textInput("edit_image_path", "Image / photo path", width = "100%"),
          textInput("edit_tags",       "Tags (semicolon-separated)", width = "100%"),
          textAreaInput("edit_notes",  "Notes", rows = 5),

          fluidRow(
            column(4, actionButton("load_selected", "Load selected post")),
            column(4, actionButton("save_changes",  "Save changes")),
            column(4, actionButton("clear_form",    "Clear form"))
          ),

          br(),
          textOutput("save_status")
        ),

        tabPanel("Status summary",      br(), tableOutput("status_summary")),
        tabPanel("Publication summary", br(), tableOutput("publication_summary"))
      )
    )
  )
)

# Local: go straight to the app; Cloud: show login screen first
ui <- if (is_local) main_ui else uiOutput("page_ui")

# ── Server ────────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

  # Local: start authenticated; Cloud: require login
  authenticated <- reactiveVal(is_local)

  # Cloud-only: login / logout / CSV download
  if (!is_local) {
    output$page_ui <- renderUI({
      if (authenticated()) main_ui else login_ui
    })

    output$login_error <- renderText("")

    observeEvent(input$login_btn, {
      if (check_login(input$login_user, input$login_pass)) {
        authenticated(TRUE)
      } else {
        output$login_error <- renderText("Incorrect username or password.")
      }
    })

    observeEvent(input$sign_out, {
      authenticated(FALSE)
    })

    output$download_csv <- downloadHandler(
      filename = function() paste0("blog_registry_", Sys.Date(), ".csv"),
      content  = function(file) write_csv(blog_data(), file, na = "")
    )
  }

  # ── Data ────────────────────────────────────────────────────────────────────

  blog_data         <- reactiveVal(NULL)
  selected_post_id  <- reactiveVal(NULL)
  original_form_data <- reactiveVal(NULL)
  has_unsaved_changes <- reactiveVal(FALSE)

  observeEvent(authenticated(), {
    req(authenticated())
    blog_data(read_blog_registry())
  })

  observe({
    req(authenticated())
    df <- blog_data()
    if (is.null(df) || nrow(df) == 0) return()
    updateSelectInput(session, "status_filter",
      choices = sort(unique(df$status)), selected = sort(unique(df$status)))
    updateSelectInput(session, "publication_filter",
      choices = sort(unique(df$publication)), selected = sort(unique(df$publication)))
  })

  observeEvent(input$refresh, {
    blog_data(read_blog_registry())
  })

  observeEvent(input$back_to_posts, {
    if (has_unsaved_changes()) {
      shinyjs::runjs("
        if (confirm('You have unsaved changes. Do you want to discard them and go back to the Posts tab?')) {
          Shiny.setInputValue('confirm_back_to_posts', true);
        }
      ")
    } else {
      updateTabsetPanel(session, "main_tabs", selected = "Posts")
    }
  })

  observeEvent(input$confirm_back_to_posts, {
    has_unsaved_changes(FALSE)
    selected_post_id(NULL)
    original_form_data(NULL)
    updateTabsetPanel(session, "main_tabs", selected = "Posts")
  })

  # ── Change detection ─────────────────────────────────────────────────────────
  
  observe({
    req(original_form_data(), selected_post_id())
    
    orig <- original_form_data()
    changed <- (
      input$edit_title != orig$title ||
      input$edit_lead_quote != orig$lead_quote ||
      input$edit_gist != orig$gist ||
      !identical(input$edit_draft_started, orig$draft_started) ||
      !identical(input$edit_published_date, orig$published_date) ||
      input$edit_status != orig$status ||
      input$edit_publication != orig$publication ||
      input$edit_path != orig$path ||
      input$edit_chart_path != orig$chart_path ||
      input$edit_image_path != orig$image_path ||
      input$edit_tags != orig$tags ||
      input$edit_notes != orig$notes
    )
    
    has_unsaved_changes(changed)
  })

  # ── Local-only: new post scaffolding ────────────────────────────────────────

  if (is_local) {
    scaffold_msg <- reactiveVal("")

    observeEvent(input$scaffold_post, {
      title <- str_trim(input$new_post_title)
      if (title == "") { scaffold_msg("Please enter a post title."); return() }

      script_path <- normalizePath(file.path(blog_root, "new_post.sh"))
      system2("bash", args = c(script_path, shQuote(title)), stdout = TRUE, stderr = TRUE)

      df          <- blog_data()
      date_prefix <- format(Sys.Date(), "%Y-%m-%d")
      year        <- format(Sys.Date(), "%Y")
      slug        <- slugify(title)
      post_path   <- paste0("posts/", year, "/", date_prefix, "-", slug)

      new_post_id <- as.character(max(as.integer(df$post_id), na.rm = TRUE) + 1L)
      qmd_file    <- file.path(blog_root, post_path, "index.qmd")
      if (file.exists(qmd_file)) {
        qmd <- readLines(qmd_file)
        qmd <- gsub("^post_id: 0", paste0("post_id: ", new_post_id), qmd)
        writeLines(qmd, qmd_file)
      }

      new_row <- tibble(
        post_id        = new_post_id,
        title          = title,
        lead_quote     = "", gist = "",
        draft_started  = Sys.Date(),
        published_date = as.Date(NA),
        status         = "idea", publication = "unassigned",
        path           = post_path,
        chart_path     = "", image_path = "",
        tags           = "", notes = ""
      )

      df <- bind_rows(df, new_row)
      write_blog_registry(df)
      blog_data(read_blog_registry())
      updateTextInput(session, "new_post_title", value = "")
      scaffold_msg(paste("Created:", post_path))
    })

    output$scaffold_status <- renderText({ scaffold_msg() })

    observeEvent(input$scaffold_existing_click, {
      post_id_clicked <- input$scaffold_existing_click$id
      df  <- blog_data()
      row <- df %>% filter(post_id == post_id_clicked) %>% slice(1)
      if (nrow(row) == 0 || row$path != "") return()

      scaffold_date <- if (!is.na(row$draft_started)) as.character(row$draft_started) else as.character(Sys.Date())
      year          <- substr(scaffold_date, 1, 4)
      slug          <- slugify(row$title)
      post_rel_path <- paste0("posts/", year, "/", scaffold_date, "-", slug)
      post_dir      <- file.path(blog_root, post_rel_path)

      if (!dir.exists(post_dir)) {
        dir.create(file.path(post_dir, "images"), recursive = TRUE)
        template_path <- file.path(blog_root, "_template", "index.qmd")
        dest_file     <- file.path(post_dir, "index.qmd")
        file.copy(template_path, dest_file)
        qmd <- readLines(dest_file)
        qmd <- gsub('^title: "Post Title"', paste0('title: "', row$title, '"'), qmd)
        qmd <- gsub('^date: today',         paste0('date: ', scaffold_date),    qmd)
        qmd <- gsub('^post_id: 0',          paste0('post_id: ', row$post_id),   qmd)
        writeLines(qmd, dest_file)
      }

      i <- match(post_id_clicked, df$post_id)
      df$path[i] <- post_rel_path
      if (is.na(df$draft_started[i])) df$draft_started[i] <- as.Date(scaffold_date)
      write_blog_registry(df)
      blog_data(read_blog_registry())
    })

    upload_msg <- reactiveVal("")

    observeEvent(input$upload_to_cloud, {
      upload_msg("Uploading...")
      tryCatch({
        # Copy local registry to the shiny bundle
        file.copy("../docs/blog_registry.csv", "blog_registry.csv", overwrite = TRUE)
        
        # Deploy to Connect Cloud
        rsconnect::deployApp(
          appDir = ".",
          appTitle = "Blog Editorial Dashboard",
          account = "westeva",
          server = "connect.posit.cloud",
          forceUpdate = TRUE
        )
        
        upload_msg("✓ Upload complete! Cloud version updated.")
      }, error = function(e) {
        upload_msg(paste("✗ Upload failed:", conditionMessage(e)))
      })
    })

    output$upload_status <- renderText({ upload_msg() })
  }

  # ── Filtered data ───────────────────────────────────────────────────────────

  filtered_data <- reactive({
    df <- blog_data()
    if (is.null(df)) return(NULL)

    if (!is.null(input$status_filter) && length(input$status_filter) > 0)
      df <- df %>% filter(status %in% input$status_filter)

    if (!is.null(input$publication_filter) && length(input$publication_filter) > 0)
      df <- df %>% filter(publication %in% input$publication_filter)

    if (!is.null(input$search_text) && input$search_text != "") {
      q  <- str_to_lower(input$search_text)
      df <- df %>% filter(
        str_detect(str_to_lower(title), fixed(q)) |
        str_detect(str_to_lower(gist),  fixed(q)) |
        str_detect(str_to_lower(tags),  fixed(q))
      )
    }

    if (isTRUE(input$missing_only))
      df <- df %>% filter(lead_quote == "" | gist == "" | status == "unassigned" | publication == "unassigned")

    # Sort by status priority: editing, drafting, scheduled, idea, published, unassigned
    status_order <- c("editing", "drafting", "scheduled", "idea", "published", "unassigned")
    df <- df %>%
      mutate(status_priority = match(status, status_order)) %>%
      arrange(status_priority) %>%
      select(-status_priority)

    df
  })

  # ── Summary counts ──────────────────────────────────────────────────────────

  output$total_posts <- renderText({
    req(blog_data()); nrow(blog_data())
  })
  output$published_posts <- renderText({
    req(blog_data())
    blog_data() %>% filter(status == "published" | !is.na(published_date)) %>% nrow()
  })
  output$unpublished_posts <- renderText({
    req(blog_data())
    blog_data() %>% filter(status != "published" | is.na(published_date)) %>% nrow()
  })
  output$missing_posts <- renderText({
    req(blog_data())
    blog_data() %>% filter(lead_quote == "" | gist == "" | status == "unassigned" | publication == "unassigned") %>% nrow()
  })

  # ── Posts table ─────────────────────────────────────────────────────────────

  output$posts_table <- renderDT({
    req(filtered_data())
    df <- filtered_data() %>%
      select(post_id, title, status, publication, published_date, path, chart_path, image_path, tags) %>%
      mutate(post_id = as.integer(post_id))

    df$doc <- if_else(
      df$path != "",
      paste0('<span title="', df$path, '" style="cursor: help; font-size: 1.2em;">&#128196;</span>'),
      '<span style="color: #ccc; font-size: 1.2em;">&#128196;</span>'
    )

    # Setup column: clickable locally, greyed out on cloud
    df$setup <- if (is_local) {
      if_else(
        df$path != "",
        '<span style="font-size: 1.2em;">&#9989;</span>',
        paste0('<a href="#" style="text-decoration: none; cursor: pointer; font-size: 1.2em;" ',
               'onclick="Shiny.setInputValue(\'scaffold_existing_click\', {id: \'',
               df$post_id, '\', time: Date.now()}); return false;" title="Scaffold post directory">&#9881;</a>')
      )
    } else {
      if_else(
        df$path != "",
        '<span style="font-size: 1.2em;">&#9989;</span>',
        '<span style="color: #ccc; font-size: 1.2em; cursor: not-allowed;" title="Scaffolding disabled in cloud deployment">&#9881;</span>'
      )
    }
    df <- df %>% select(-path)

    make_dot <- function(filled) if_else(filled,
      '<span style="color: green; font-size: 1.4em;">&#9679;</span>',
      '<span style="color: red;   font-size: 1.4em;">&#9679;</span>'
    )
    df$chart <- make_dot(df$chart_path != "")
    df$image <- make_dot(df$image_path != "")
    df$tags  <- make_dot(df$tags != "")
    df <- df %>% select(-chart_path, -image_path)

    df$title <- paste0(
      '<a href="#" style="color: #0066cc; text-decoration: none; cursor: pointer;" ',
      'onclick="Shiny.onInputChange(\'edit_post_click\', {id: \'', df$post_id, '\', time: Date.now()}); return false;">',
      df$title, '</a>'
    )

    # Capture priority BEFORE status is overwritten with HTML
    status_order <- c("editing", "drafting", "scheduled", "idea", "published", "unassigned")
    df$status_priority <- match(df$status, status_order)

    status_color <- case_when(
      df$status == "unassigned" ~ "red",
      df$status == "published"  ~ "green",
      TRUE ~ "blue"
    )
    df$status <- paste0(
      '<select class="status-select" data-post-id="', df$post_id,
      '" style="min-width: 110px; width: 100%; border: none; outline: none; background: transparent; color: ',
      status_color, '; font-weight: bold;">',
      '<option value="idea"',       if_else(df$status == "idea",       " selected", ""), '>idea</option>',
      '<option value="drafting"',   if_else(df$status == "drafting",   " selected", ""), '>drafting</option>',
      '<option value="editing"',    if_else(df$status == "editing",    " selected", ""), '>editing</option>',
      '<option value="scheduled"',  if_else(df$status == "scheduled",  " selected", ""), '>scheduled</option>',
      '<option value="published"',  if_else(df$status == "published",  " selected", ""), '>published</option>',
      '<option value="unassigned"', if_else(df$status == "unassigned", " selected", ""), '>unassigned</option>',
      '</select>'
    )

    publication_color <- if_else(df$publication == "unassigned", "red", "black")
    df$publication <- paste0(
      '<select class="publication-select" data-post-id="', df$post_id,
      '" style="width: 100%; border: none; outline: none; background: transparent; color: ', publication_color, ';">',
      '<option value="unassigned"', if_else(df$publication == "unassigned", " selected", ""), '>unassigned</option>',
      '<option value="substack"',   if_else(df$publication == "substack",   " selected", ""), '>substack</option>',
      '<option value="website"',    if_else(df$publication == "website",    " selected", ""), '>website</option>',
      '<option value="both"',       if_else(df$publication == "both",       " selected", ""), '>both</option>',
      '</select>'
    )

    df$delete <- paste0(
      '<a href="#" style="color: red; text-decoration: none; cursor: pointer; font-size: 1.2em;" ',
      'onclick="if(confirm(\'Are you sure you want to delete this post?\\n\\nThis cannot be undone.\')) { ',
      'Shiny.setInputValue(\'delete_post_click\', {id: \'', df$post_id, '\', time: Date.now()}); } return false;" ',
      'title="Delete post">&#10060;</a>'
    )

    # status_priority (col 1) is hidden; clicking Status (col 6) sorts by it
    df <- df %>% select(post_id, status_priority, doc, setup, title, status, publication, published_date, chart, image, tags, delete)

    datatable(df, escape = FALSE, selection = "none", rownames = FALSE,
      colnames = c("post_id", "sp", "", "Setup", "Title", "Status", "Publication", "Published", "Chart", "Image", "Tags", ""),
      options = list(
        pageLength = 15, scrollX = TRUE,
        order = list(list(1, "asc")),
        columnDefs = list(
          list(visible = FALSE, targets = c(0, 1)),
          list(width = "30px", className = "dt-center", targets = c(2, 3, 8, 9, 10, 11)),
          list(orderData = 1, targets = 5)
        )
      )
    )
  })

  output$status_summary      <- renderTable({ req(filtered_data()); filtered_data() %>% count(status, sort = TRUE) })
  output$publication_summary <- renderTable({ req(filtered_data()); filtered_data() %>% count(publication, sort = TRUE) })

  # ── Edit tab title with unsaved changes indicator ────────────────────────────
  
  output$edit_tab_title <- renderUI({
    title <- "Edit selected post"
    if (has_unsaved_changes()) {
      title <- paste0(title, " *")
    }
    title
  })

  # ── Edit post ───────────────────────────────────────────────────────────────

  observeEvent(input$edit_post_click, {
    post_id_clicked <- input$edit_post_click$id
    df  <- blog_data()
    row <- df %>% filter(post_id == post_id_clicked) %>% slice(1)
    if (nrow(row) == 0) { selected_post_id(NULL); return() }

    # Store the original form data for change detection
    original_form_data(list(
      title = row$title,
      lead_quote = row$lead_quote,
      gist = row$gist,
      draft_started = row$draft_started,
      published_date = row$published_date,
      status = row$status,
      publication = row$publication,
      path = row$path,
      chart_path = row$chart_path,
      image_path = row$image_path,
      tags = row$tags,
      notes = row$notes
    ))
    
    selected_post_id(row$post_id)
    has_unsaved_changes(FALSE)
    updateTextInput(session,     "edit_title",        value = row$title)
    updateTextAreaInput(session, "edit_lead_quote",   value = row$lead_quote)
    updateTextAreaInput(session, "edit_gist",         value = row$gist)
    updateDateInput(session,     "edit_draft_started",  value = row$draft_started)
    updateDateInput(session,     "edit_published_date", value = row$published_date)
    updateSelectInput(session,   "edit_status",       selected = row$status)
    updateSelectInput(session,   "edit_publication",  selected = row$publication)
    updateTextInput(session,     "edit_path",         value = row$path)
    updateTextInput(session,     "edit_chart_path",   value = row$chart_path)
    updateTextInput(session,     "edit_image_path",   value = row$image_path)
    updateTextInput(session,     "edit_tags",         value = row$tags)
    updateTextAreaInput(session, "edit_notes",        value = row$notes)
    updateTabsetPanel(session, "main_tabs", selected = "edit_tab")
  })

  observeEvent(input$save_changes, {
    req(selected_post_id())
    df <- blog_data()
    i  <- match(selected_post_id(), df$post_id)
    req(!is.na(i))

    norm_date <- function(x) {
      if (is.null(x)) return(NA_character_)
      if (length(x) == 0) return(NA_character_)
      if (is.na(x[1])) return(NA_character_)
      if (trimws(as.character(x[1])) == "") return(NA_character_)
      
      tryCatch(
        as.character(as.Date(x[1])),
        error = function(e) NA_character_
      )
    }

    df$title[i]         <- input$edit_title
    df$lead_quote[i]    <- input$edit_lead_quote
    df$gist[i]          <- input$edit_gist
    df$draft_started[i] <- norm_date(input$edit_draft_started)
    df$published_date[i]<- norm_date(input$edit_published_date)
    df$status[i]        <- input$edit_status
    df$publication[i]   <- input$edit_publication
    df$path[i]          <- input$edit_path
    df$chart_path[i]    <- input$edit_chart_path
    df$image_path[i]    <- input$edit_image_path
    df$tags[i]          <- input$edit_tags
    df$notes[i]         <- input$edit_notes

    write_blog_registry(df)
    blog_data(read_blog_registry())
    has_unsaved_changes(FALSE)
    original_form_data(NULL)
  })

  observeEvent(input$clear_form, {
    selected_post_id(NULL)
    has_unsaved_changes(FALSE)
    original_form_data(NULL)
    updateTextInput(session,     "edit_title",          value = "")
    updateTextAreaInput(session, "edit_lead_quote",     value = "")
    updateTextAreaInput(session, "edit_gist",           value = "")
    updateDateInput(session,     "edit_draft_started",  value = NA)
    updateDateInput(session,     "edit_published_date", value = NA)
    updateSelectInput(session,   "edit_status",         selected = "unassigned")
    updateSelectInput(session,   "edit_publication",    selected = "unassigned")
    updateTextInput(session,     "edit_path",           value = "")
    updateTextInput(session,     "edit_chart_path",     value = "")
    updateTextInput(session,     "edit_image_path",     value = "")
    updateTextInput(session,     "edit_tags",           value = "")
    updateTextAreaInput(session, "edit_notes",          value = "")
  })

  # ── Delete post ─────────────────────────────────────────────────────────────

  observeEvent(input$delete_post_click, {
    post_id_clicked <- input$delete_post_click$id
    df  <- blog_data()
    row <- df %>% filter(post_id == post_id_clicked) %>% slice(1)

    if (is_local && nrow(row) == 1 && row$path != "") {
      post_dir <- file.path(blog_root, row$path)
      if (dir.exists(post_dir)) {
        archive_dir <- file.path(blog_root, "archive", row$path)
        dir.create(dirname(archive_dir), recursive = TRUE, showWarnings = FALSE)
        file.rename(post_dir, archive_dir)
      }
    }

    df <- df %>% filter(post_id != post_id_clicked)
    write_blog_registry(df)
    blog_data(read_blog_registry())
  })

  # ── Inline dropdown updates ─────────────────────────────────────────────────

  observeEvent(input$update_cell_click, {
    post_id_clicked <- input$update_cell_click$id
    field     <- input$update_cell_click$field
    new_value <- input$update_cell_click$value
    df <- blog_data()
    i  <- match(post_id_clicked, df$post_id)
    if (!is.na(i)) {
      df[[field]][i] <- new_value
      write_blog_registry(df)
      blog_data(read_blog_registry())
    }
  })

  # ── Status text ─────────────────────────────────────────────────────────────

  output$selected_post_id <- renderText({
    if (is.null(selected_post_id())) "No post loaded." else paste("Loaded post:", selected_post_id())
  })

  output$save_status <- renderText({
    if (is.null(selected_post_id())) "Select a row in the Posts tab, then click 'Load selected post'."
    else paste("Ready to edit:", selected_post_id())
  })
}

shinyApp(ui = ui, server = server)
