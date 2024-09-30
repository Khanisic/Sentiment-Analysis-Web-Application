
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")

if (!requireNamespace("stringr", quietly = TRUE)) install.packages("stringr")
if (!requireNamespace("tm", quietly = TRUE)) install.packages("tm")

if (!requireNamespace("tidyr", quietly = TRUE)) install.packages("tidyr")
if (!requireNamespace("tibble", quietly = TRUE)) install.packages("tibble")
if (!requireNamespace("tidy", quietly = TRUE)) install.packages("tidytext")
if (!requireNamespace("shinyjs", quietly = TRUE)) install.packages("shinyjs")


library(shinyjs)
library(tidytext)
library(shiny)
library(plotly)
library(dplyr)
library(tidyr)
library(shinyWidgets)
library(syuzhet)
library(tm)



source("ui.R")
source("server.R")

shinyApp(ui = ui, server = server)
