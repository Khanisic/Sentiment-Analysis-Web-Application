
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")

if (!requireNamespace("stringr", quietly = TRUE)) install.packages("stringr")
if (!requireNamespace("tm", quietly = TRUE)) install.packages("tm")


if (!requireNamespace("tibble", quietly = TRUE)) install.packages("tibble")

if (!requireNamespace("tidyr", quietly = TRUE)) install.packages("tidyr")
if (!requireNamespace("tidytext", quietly = TRUE)) install.packages("tidytext")
if (!requireNamespace("tidyverse", quietly = TRUE)) install.packages("tidyverse")



library(tidytext)
library(dplyr)
library(tidyr)
library(tibble)
library(stringr)
library(tm)
library(tidyverse)


cache <- new.env(parent = emptyenv())

server <- function(input, output) {

  shinyjs::hide("progress-outer")
  toggle_state <- reactiveVal(FALSE)

  observeEvent(input$toggle, {
    toggle_state(!toggle_state()) 
  })


  final_data <- eventReactive(input$searchBtn, {#

    shinyjs::show("progress-outer")
  
    shinyjs::html("progress-text", "Starting data processing...")
    print(input$searchTerms)
    modified_search_string <- gsub(", ", "_", input$searchTerms)
    cache_key <- paste("dates", input$numberRange[1], input$numberRange[2], "search", modified_search_string, sep = "_") # nolint: line_length_linter.
    # original_string <- "dates_3_5_search_voting_applem_orange"


    # dates_string <- gsub("dates_([0-9]+)_([0-9]+).*", "\\1 \\2", cache_key)
    # dates_array <- as.numeric(strsplit(dates_string, " ")[[1]])

    words_string <- gsub(".*search_(.*)", "\\1", cache_key)
    words_array <- unlist(strsplit(words_string, "_"))


    selected_files <- paste0(input$numberRange[1]:input$numberRange[2], ".csv")

    print(selected_files)
    folder_path <- "day_wise_csv_tweets/"

    all_tweets <- data.frame()
    row_wise_sentiment_scores_only <- data.frame()
    just_tweets_text <- data.frame()

    for( selected_word in words_array){

      for (file_name in selected_files) {

      shinyjs::html("progress-text", paste("Analyzing word: ", selected_word, "in ", file_name))
        print(paste("file", file_name,"word", selected_word))

        new_file_name <- paste0(selected_word, "_", file_name)
        full_path <- file.path("cache", trimws(new_file_name))

        file_path <- paste0(folder_path, file_name)

        if (file.exists(full_path)) {
      
          cache_file <- read.csv(full_path, stringsAsFactors = FALSE)
          all_tweets <- rbind(all_tweets, cache_file)

          print(paste("Found ",full_path," from cache"))
        }
        else {
          tweets_df <- read.csv(file_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8", quote = "\"")
       
          search_expression <- paste0("(", paste(selected_word, collapse = "|"), ")")
          filtered_tweets <- tweets_df %>%
            filter(grepl(search_expression, text, ignore.case = TRUE))
          tweets_corpus <- Corpus(VectorSource(filtered_tweets$text))
          tweets_corpus <- tm_map(tweets_corpus, content_transformer(tolower))
          tweets_corpus <- tm_map(tweets_corpus, removePunctuation)
          tweets_corpus <- tm_map(tweets_corpus, removeWords, stopwords("english"))
          preprocessed_tweets <- sapply(tweets_corpus, as.character)
          filtered_tweets$text <- preprocessed_tweets
          filtered_tweets$text <- as.character(filtered_tweets$text)
          filtered_tweets$text <- filtered_tweets$text[!is.na(filtered_tweets$text) & filtered_tweets$text != ""]

          sentiment_scores <- get_nrc_sentiment(filtered_tweets$text)
          
          row_wise_sentiment_scores_only <- rbind(row_wise_sentiment_scores_only, sentiment_scores)
          just_tweets_text <- rbind(just_tweets_text, filtered_tweets)

          cache_file <- cbind(filtered_tweets, sentiment_scores)

          new_file_name <- paste0(selected_word, "_", file_name)
          full_path <- file.path("cache", trimws(new_file_name))

          write.csv(cache_file, full_path,row.names = FALSE)

          all_tweets <- rbind(all_tweets, cache_file)
        }

      }
    }
    write.csv(all_tweets, "test.csv", row.names = FALSE)

    shinyjs::html("progress-text", "Done filtering...")
    


    shinyjs::html("progress-text", "Counting tweets and words")

    tweets_by_state <- all_tweets %>%
      group_by(state) %>%
      summarise(number_of_tweets = n())
      
#################################################

    word_count <- all_tweets %>%
      unnest_tokens(word, text) %>%
      filter(!word %in% c("rt", "voting")) %>% 
      count(state, word, sort = TRUE) %>%
      group_by(state) 

    word_and_freq <- all_tweets %>%
      unnest_tokens(word, text) %>%
      filter(!word %in% c("rt", "voting")) %>% 
      count(word, sort = TRUE) %>%
      filter(n > 30) %>% 
      rename(word = word, freq = n) 

    word_and_freq$word <- as.character(word_and_freq$word)

    filter_words <- function(words_string) {
      words <- strsplit(words_string, ", ")[[1]]
      filtered_words <- words[words %in% word_and_freq$word]
      return(paste(filtered_words, collapse = ", "))
    }

    top_words_by_state <- word_count %>%
      group_by(state) %>%
      summarise(top_5 = paste(word, collapse = ", ")) %>%
      as.data.frame()

    top_words_by_state$top_5_filtered <- sapply(top_words_by_state$top_5, filter_words)

    final <- top_words_by_state %>%
      mutate(top_5 = sapply(strsplit(top_5, ","), function(x) paste(head(x, 5), collapse = ",")))

###################################################################################################

    final_df <- left_join(tweets_by_state, final, by = "state")
 

    shinyjs::html("progress-text", "Working on aggregating")

    state_emotion_totals <- all_tweets %>%
      group_by(code) %>%
      summarise(
        n_tweets = n(),
        total_anger = sum(anger),
        total_anticipation = sum(anticipation),
        total_disgust = sum(disgust),
        total_fear = sum(fear),
        total_joy = sum(joy),
        total_negative = sum(negative),
        total_positive = sum(positive),
        total_sadness = sum(sadness),
        total_surprise = sum(surprise),
        total_trust = sum(trust),
        .groups = "drop"
      )

    data_scaled <- state_emotion_totals %>%
      mutate(
        total_anger = (total_anger / n_tweets) * 100,
        total_anticipation = (total_anticipation / n_tweets) * 100,
        total_disgust = (total_disgust / n_tweets) * 100,
        total_fear = (total_fear / n_tweets) * 100,
        total_joy = (total_joy / n_tweets) * 100,
        total_negative = (total_negative / n_tweets) * 100,
        total_positive = (total_positive / n_tweets) * 100,
        total_sadness = (total_sadness / n_tweets) * 100,
        total_surprise = (total_surprise / n_tweets) * 100,
        total_trust = (total_trust / n_tweets) * 100
      )
    
    normalize <- function(x, min_range = 1, max_range = 100) {
      return ((x - min(x)) / (max(x) - min(x)) * (max_range - min_range) + min_range)
    }

    shinyjs::html("progress-text", "Normalizing data")

    data_normalized <- data_scaled %>%
      mutate(across(-code, normalize))



    data_cleaned <- select(state_emotion_totals, -total_negative, -total_positive)
    colnames(data_cleaned)[3:ncol(data_cleaned)] <- sub("total_", "", colnames(data_cleaned)[3:ncol(data_cleaned)])
    colnames(data_cleaned)[3:ncol(data_cleaned)] <- sapply(strsplit(colnames(data_cleaned)[3:ncol(data_cleaned)], "_"), function(x) {
      paste(toupper(substring(x, 1, 1)), substring(x, 2), sep = "", collapse = " ")
    })

    data_long <- pivot_longer(data_cleaned, -c(code, n_tweets), names_to = "emotion", values_to = "value")

    highest_emotion_each_state <- data_long %>%
      group_by(code) %>%
      filter(value == max(value)) %>%
      slice(1) %>%
      ungroup() %>%
      select(code, highest = emotion)





    shinyjs::html("progress-text", "Done!!")

    shinyjs::hide("progress-outer")
    return(list(data_normalized, word_and_freq, final_df,highest_emotion_each_state))
  })

  output$map <- renderPlotly({


    highest_emotion_each_state <- final_data()[[4]]
    emotion_colors <- c(
      'Anger' = "red", "Anticipation" = "yellow", "Disgust" = "brown", "Fear" = "darkorange",
      "Joy" = "skyblue", "Sadness" = "lightpink", "Surprise" = "violet", 'Trust' = "lightblue"
    )

    if (!toggle_state()) {
      final_df <- final_data()[[1]]
      print("Final df received")
      custom_colorscale <- list(
        list(0, "#95d3be"),
        list(0.5, "#4d6c62"),
        list(1, "#050505")
      )

      emotion_column <- switch(input$emotion,
        "Anger" = "total_anger",
        "Anticipation" = "total_anticipation",
        "Disgust" = "total_disgust",
        "Fear" = "total_fear",
        "Joy" = "total_joy",
        "Negative" = "total_negative",
        "Positive" = "total_positive",
        "Sadness" = "total_sadness",
        "Surprise" = "total_surprise",
        "Trust" = "total_trust"
      )

      plot_ly(
        data = final_df, type = "choropleth",
        locationmode = "USA-states",
        colorscale = custom_colorscale,
        locations = ~code,
        z = final_df[[emotion_column]],
        text = ~ paste("Emotion Score out of 100: ", round(get(emotion_column)))
      ) %>%
        layout(title = paste("Selected emotion: ", input$emotion), geo = list(scope = "usa", paper_bgcolor = "rgba(32, 26, 54, 1)"), mapbox = list(style = "light")) # nolint
    } else {
      highest_emotion_each_state$emotion_numeric <- as.integer(factor(highest_emotion_each_state$highest))

      plot_ly(data = highest_emotion_each_state, type = 'choropleth',
              locationmode = 'USA-states',
              locations = ~code,
              z = ~emotion_numeric, 
              text = ~paste("State: ", code, "<br>", "Emotion: ", highest),
              colors = emotion_colors) %>% 
        layout(title = "Map of Highest Emotion by State", geo = list(scope = 'usa', showland = FALSE, paper_bgcolor  = 'rgba(32, 26, 54, 1)'), mapbox = list(style = "light")) %>%
        colorbar(title = "Emotion", tickvals = 1:length(emotion_colors), ticktext = names(emotion_colors))
    }

  })

  output$topEight <- renderUI({
  
    word_and_freq <- final_data()[[2]]
    words <- head(word_and_freq$word, n = 8) 
    
    tags$div(class = "top-inner",
    p(id="top-5-title","Top 8 words: "),
      lapply(words, function(word) {
      
        tags$p(word, class = "word-class")
      })
    )
  })

  output$statsInfo <- renderUI({
  
    final_df <- final_data()[[3]]
    states <- head(final_df$state, n = 49)
    number_of_tweets <- head(final_df$number_of_tweets, n = 49)
    top_5 <- head(final_df$top_5, n=49)
    
    div(class = "stats-outer",
      div(class = "statsInfo-state",
        lapply(states, function(word) {
          tags$p(word, class = "info-inner")
        }),
      ),
      div(class = "statsInfo-number",
        lapply(number_of_tweets, function(word) {
          tags$p(word, class = "info-inner")
        })
      ),
      div(class = "statsInfo-top-5",
        lapply(top_5, function(commaSeparatedWords) {
          words <- strsplit(commaSeparatedWords, ", ")[[1]]
          div(class= "statsInfo-top-5-inner",
            lapply(words, function(word) {
              tags$p(word, class = "info-inner-5")
            })
          )
        })
      ),
    )
  })
}
