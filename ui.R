library(shiny)
library(plotly)
library(dplyr)
library(shinyWidgets)
library(syuzhet)
library(tm)
library("tidyr", quietly = TRUE)
library(wordcloud2)
library(shinyjs)

ui <- fluidPage(
  tags$head(
    tags$link(href="https://fonts.googleapis.com/css2?family=Roboto+Slab:wght@100..900&display=swap", rel="stylesheet")
  ),
  includeCSS("app_styles.css"),
  useShinyjs(),
  p(id="main_title","USA State-wise sentiment map"),
  div(class = "sidebar",
    div(class = "form-section",
      div(class = "form-inner-section",
        textInput("searchTerms", "Enter search terms (comma-separated):", "voting"),
        actionButton("searchBtn", "Search"),
        actionButton("toggle", "Toggle Best Emotions"),
      ),
        sliderInput("numberRange", "Select date range:",
                    min = 1, max = 31, value = c(3, 5),  # Default range from 3 to 13
                    step = 1),
        ),
        div(class = "dropdown-emotions",
        selectInput("emotion", "Select Emotion:",
                    choices = c("Anger", "Anticipation", "Disgust", "Fear", "Joy", "Negative", "Positive", "Sadness", "Surprise", "Trust"),
                    selected = "Anger")),
        div(class = "map-section",
        plotlyOutput("map", width = "100%", height = "100%"),
        div(class = "stats-table",
          uiOutput("topEight"),
        ), 
      ),
  ),
  div(class="stats",
    div(id = "progress-outer",
      div(id="progress-inner",
        div(id="progress-loader"),
        div(id="progress-text"))),
    p(id="stats_title","State-wise word frequency"),
    div(class = "stats-table",
      div(class="stats-headings",
        p(class="stat-heading","State"),
        p(class="stat-heading","Number of tweets"),
        p(class="stat-heading","Frequent words"),
      ),
      uiOutput("statsInfo"),
    ),
  ),
)