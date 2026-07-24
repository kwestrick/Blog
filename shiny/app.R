library(shiny)
library(readr)
library(dplyr)
library(stringr)
library(DT)

registry_path <- "../docs/blog_registry.csv"

read_blog_registry <- function(path = registry_path) {
  read_csv(path, show_col_types = FALSE) %>%
    mutate(
      idea_date = as.Date(idea_date),
      draft_started = as.Date(draft_started),
      published_date = as.Date(published_date),
      post_id = coalesce(post_id, ""),
      title = coalesce(title, ""),
      lead_quote = coalesce(lead_quote, ""),
      gist = coalesce(gist, ""),
      publication = str_trim(tolower(coalesce(publication, ""))),
      status = str_trim(tolower(coalesce(status, ""))),
      path = coalesce(path, ""),
      assets = coalesce(assets, ""),
      substack_url = coalesce(substack_url, ""),
      website_url = coalesce(website_url, ""),
      notes = coalesce(notes, ""),
      r_project = coalesce(r_project, ""),
      tags = coalesce(tags, "")
    ) %>%
    mutate(
      publication = if_else(publication == "", "unassigned", publication),
      status = if_else(status == "", "unassigned", status)
    )
}

write_blog_registry <- function(df, path = registry_path) {
  write_csv(df, path, na = "")
}

ui <- fluidPage(
  titlePanel("Blog Workflow Dashboard"),
  
  sidebarLayout(
    sidebarPanel(
      actionButton("refresh", "Refresh data"),
      br(), br(),
      
      selectInput("status_filter", "Status", choices = NULL, multiple = TRUE),
      selectInput("publication_filter", "Publication", choices = NULL, multiple = TRUE),
      textInput("search_text", "Search title / gist / tags", value = ""),
      checkboxInput("missing_only", "Show only posts missing key metadata", value = FALSE),
      
      width = 3
    ),
    
    mainPanel(
      fluidRow(
        column(3, wellPanel(h4("Total posts"), textOutput("total_posts"))),
        column(3, wellPanel(h4("Published"), textOutput("published_posts"))),
        column(3, wellPanel(h4("Unpublished"), textOutput("unpublished_posts"))),
        column(3, wellPanel(h4("Missing fields"), textOutput("missing_posts")))
      ),
      
      tabsetPanel(
        tabPanel(
          "Posts",
          br(),
          DTOutput("posts_table")
        ),
        
        tabPanel(
          "Edit selected post",
          br(),
          verbatimTextOutput("selected_post_id"),
          
          textInput("edit_title", "Title"),
          textAreaInput("edit_lead_quote", "Lead quote", rows = 3),
          textAreaInput("edit_gist", "Gist", rows = 4),
          
          fluidRow(
            column(4, dateInput("edit_idea_date", "Idea date")),
            column(4, dateInput("edit_draft_started", "Draft started")),
            column(4, dateInput("edit_published_date", "Published date"))
          ),
          
          fluidRow(
            column(6,
                   selectInput(
                     "edit_status",
                     "Status",
                     choices = c("idea", "drafting", "editing", "scheduled", "published", "unassigned")
                   )
            ),
            column(6,
                   selectInput(
                     "edit_publication",
                     "Publication",
                     choices = c("unassigned", "substack", "website", "both")
                   )
            )
          ),
          
          textInput("edit_path", "Path"),
          textInput("edit_assets", "Assets"),
          textInput("edit_substack_url", "Substack URL"),
          textInput("edit_website_url", "Website URL"),
          textInput("edit_r_project", "R project"),
          textInput("edit_tags", "Tags (semicolon-separated)"),
          textAreaInput("edit_notes", "Notes", rows = 5),
          
          fluidRow(
            column(4, actionButton("load_selected", "Load selected post")),
            column(4, actionButton("save_changes", "Save changes")),
            column(4, actionButton("clear_form", "Clear form"))
          ),
          
          br(),
          textOutput("save_status")
        ),
        
        tabPanel(
          "Status summary",
          br(),
          tableOutput("status_summary")
        ),
        
        tabPanel(
          "Publication summary",
          br(),
          tableOutput("publication_summary")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  
  blog_data <- reactiveVal(read_blog_registry())
  selected_post_id <- reactiveVal(NULL)
  
  observe({
    df <- blog_data()
    
    updateSelectInput(
      session, "status_filter",
      choices = sort(unique(df$status)),
      selected = sort(unique(df$status))
    )
    
    updateSelectInput(
      session, "publication_filter",
      choices = sort(unique(df$publication)),
      selected = sort(unique(df$publication))
    )
  })
  
  observeEvent(input$refresh, {
    blog_data(read_blog_registry())
  })
  
  filtered_data <- reactive({
    df <- blog_data()
    
    if (!is.null(input$status_filter) && length(input$status_filter) > 0) {
      df <- df %>% filter(status %in% input$status_filter)
    }
    
    if (!is.null(input$publication_filter) && length(input$publication_filter) > 0) {
      df <- df %>% filter(publication %in% input$publication_filter)
    }
    
    if (!is.null(input$search_text) && input$search_text != "") {
      query <- str_to_lower(input$search_text)
      df <- df %>%
        filter(
          str_detect(str_to_lower(title), fixed(query)) |
            str_detect(str_to_lower(gist), fixed(query)) |
            str_detect(str_to_lower(tags), fixed(query))
        )
    }
    
    if (isTRUE(input$missing_only)) {
      df <- df %>%
        filter(
          lead_quote == "" |
            gist == "" |
            status == "unassigned" |
            publication == "unassigned"
        )
    }
    
    df
  })
  
  output$total_posts <- renderText({
    nrow(blog_data())
  })
  
  output$published_posts <- renderText({
    blog_data() %>%
      filter(status == "published" | !is.na(published_date)) %>%
      nrow()
  })
  
  output$unpublished_posts <- renderText({
    blog_data() %>%
      filter(status != "published" | is.na(published_date)) %>%
      nrow()
  })
  
  output$missing_posts <- renderText({
    blog_data() %>%
      filter(
        lead_quote == "" |
          gist == "" |
          status == "unassigned" |
          publication == "unassigned"
      ) %>%
      nrow()
  })
  
  output$posts_table <- renderDT({
    filtered_data() %>%
      select(post_id, title, status, publication, idea_date, published_date, tags, path) %>%
      datatable(
        selection = "single",
        options = list(pageLength = 15, scrollX = TRUE)
      )
  })
  
  output$status_summary <- renderTable({
    filtered_data() %>% count(status, sort = TRUE)
  })
  
  output$publication_summary <- renderTable({
    filtered_data() %>% count(publication, sort = TRUE)
  })
  
  observeEvent(input$load_selected, {
    s <- input$posts_table_rows_selected
    df <- filtered_data()
    
    if (length(s) != 1 || nrow(df) < s) {
      selected_post_id(NULL)
      return()
    }
    
    row <- df[s, ]
    selected_post_id(row$post_id)
    
    updateTextInput(session, "edit_title", value = row$title)
    updateTextAreaInput(session, "edit_lead_quote", value = row$lead_quote)
    updateTextAreaInput(session, "edit_gist", value = row$gist)
    
    updateDateInput(session, "edit_idea_date", value = row$idea_date)
    updateDateInput(session, "edit_draft_started", value = row$draft_started)
    updateDateInput(session, "edit_published_date", value = row$published_date)
    
    updateSelectInput(session, "edit_status", selected = row$status)
    updateSelectInput(session, "edit_publication", selected = row$publication)
    
    updateTextInput(session, "edit_path", value = row$path)
    updateTextInput(session, "edit_assets", value = row$assets)
    updateTextInput(session, "edit_substack_url", value = row$substack_url)
    updateTextInput(session, "edit_website_url", value = row$website_url)
    updateTextInput(session, "edit_r_project", value = row$r_project)
    updateTextInput(session, "edit_tags", value = row$tags)
    updateTextAreaInput(session, "edit_notes", value = row$notes)
  })
  
  observeEvent(input$clear_form, {
    selected_post_id(NULL)
    
    updateTextInput(session, "edit_title", value = "")
    updateTextAreaInput(session, "edit_lead_quote", value = "")
    updateTextAreaInput(session, "edit_gist", value = "")
    updateDateInput(session, "edit_idea_date", value = NA)
    updateDateInput(session, "edit_draft_started", value = NA)
    updateDateInput(session, "edit_published_date", value = NA)
    updateSelectInput(session, "edit_status", selected = "unassigned")
    updateSelectInput(session, "edit_publication", selected = "unassigned")
    updateTextInput(session, "edit_path", value = "")
    updateTextInput(session, "edit_assets", value = "")
    updateTextInput(session, "edit_substack_url", value = "")
    updateTextInput(session, "edit_website_url", value = "")
    updateTextInput(session, "edit_r_project", value = "")
    updateTextInput(session, "edit_tags", value = "")
    updateTextAreaInput(session, "edit_notes", value = "")
  })
  
  observeEvent(input$save_changes, {
    req(selected_post_id())
    
    df <- blog_data()
    i <- match(selected_post_id(), df$post_id)
    
    req(!is.na(i))
    
    normalize_date <- function(x) {
      if (is.null(x) || is.na(x) || x == "") NA else as.character(as.Date(x))
    }
    
    df$title[i] <- input$edit_title
    df$lead_quote[i] <- input$edit_lead_quote
    df$gist[i] <- input$edit_gist
    df$idea_date[i] <- normalize_date(input$edit_idea_date)
    df$draft_started[i] <- normalize_date(input$edit_draft_started)
    df$published_date[i] <- normalize_date(input$edit_published_date)
    df$status[i] <- input$edit_status
    df$publication[i] <- input$edit_publication
    df$path[i] <- input$edit_path
    df$assets[i] <- input$edit_assets
    df$substack_url[i] <- input$edit_substack_url
    df$website_url[i] <- input$edit_website_url
    df$r_project[i] <- input$edit_r_project
    df$tags[i] <- input$edit_tags
    df$notes[i] <- input$edit_notes
    
    write_blog_registry(df, registry_path)
    blog_data(read_blog_registry())
  })
  
  output$selected_post_id <- renderText({
    if (is.null(selected_post_id())) {
      "No post loaded."
    } else {
      paste("Loaded post:", selected_post_id())
    }
  })
  
  output$save_status <- renderText({
    if (is.null(selected_post_id())) {
      "Select a row in the Posts tab, then click 'Load selected post'."
    } else {
      paste("Ready to edit:", selected_post_id())
    }
  })
}

shinyApp(ui = ui, server = server)
