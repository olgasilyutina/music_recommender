library(rvest)
library(dplyr)
library(readr)
library(shiny)
library(shinythemes)
library(plotly)
library(DT)
library(shinydashboard)

source("~/offline_music_recommender/get_href.R")
#source("~/offline_music_recommender/getMusicRec.R")
source("~/offline_music_recommender/get_table.R")
setwd("~/offline_music_recommender")

all_recommendation <- read.csv("/students/agbataeva/rec_for_user.csv")
all_recommendation <- na.omit(all_recommendation)
tracks_rec <- all_recommendation %>% select("artist_name", "track_title")
colnames(tracks_rec) <- c("Artist", "Title")
tracks_rec <- as.data.frame(tracks_rec)
tracks_to_show <- all_recommendation[,c(13, 5:10)]
colnames(tracks_to_show)[1] <- "group"
tracks_to_show$num <- rep(1:nrow(tracks_to_show))
tracks_to_show[is.na(tracks_to_show)] <- 0

navbarPageWithInputs <- function(..., inputs) {
  navbar <- navbarPage(...)
  form <- tags$form(class = "navbar-form", inputs)
  navbar[[3]][[1]]$children[[1]] <- htmltools::tagAppendChild(
    navbar[[3]][[1]]$children[[1]], form)
  navbar
}

ui <- fluidPage(theme = shinytheme("united"),
                tags$style(type="text/css",
                           ".shiny-output-error { visibility: hidden; }",
                           ".shiny-output-error:before { visibility: hidden; }"
                ),
                navbarPageWithInputs(HTML("MUZ recommender system for FMA"), tabPanel("Recommendations", dashboardPage(dashboardHeader(disable = T),
                                                                                                                       dashboardSidebar(disable = T),
                                                                                                                       dashboardBody(uiOutput("MainBody")
                                                                                                                                     
                                                                                                                       ))), tabPanel("My playlist", dashboardPage(dashboardHeader(disable = T),
                                                                                                                                                                  dashboardSidebar(disable = T),
                                                                                                                                                                  dashboardBody(dataTableOutput("table")))),
                                     inputs = textInput("user_name", NULL, placeholder = "User name")))

server <- function(input, output) {
  output$table <- renderDataTable({ get_table(input$user_name) }, escape=FALSE)
  
  output$MainBody<-renderUI({
    fluidPage(
      box(width=12,
          h3(strong(""),align="center"),
          hr(),
          column(6,offset = 6,
                 HTML('<div class="btn-group" role="group" aria-label="Basic example">'),
                 actionButton(inputId = "Compare_row_head",label = "Compare selected tracks"),
                 HTML('</div>')
          ),
          
          column(12,dataTableOutput("result")),
          tags$script(HTML('$(document).on("click", "input", function () {
                           var checkboxes = document.getElementsByName("row_selected");
                           var checkboxesChecked = [];
                           for (var i=0; i<checkboxes.length; i++) {
                           if (checkboxes[i].checked) {
                           checkboxesChecked.push(checkboxes[i].value);
                           }
                           }
                           Shiny.onInputChange("checked_rows",checkboxesChecked);
  })'))))})

  
  output$result <- renderDataTable({
    tracks_rec[["Select"]]<-paste0('<input type="checkbox" name="row_selected" value="Row',1:nrow(tracks_rec),'">')
    tracks_rec[["Album"]]<-paste0(sprintf('<img src="%s" height="52"></img>', as.character(all_recommendation$track_image_file)))
    tracks_rec[["Actions"]]<-
      paste0('<div class="btn-group" role="group" aria-label="Basic example">
             <img src="https://roneelprasad.files.wordpress.com/2014/05/tinder-like.png" height="52"></img>')
    datatable(tracks_rec,
              escape=F)}
      )
  
  
  observeEvent(input$Compare_row_head,{
    tracks_to_show_new <<- reactive({row_to_com <-as.numeric(gsub("Row","",input$checked_rows))
    number_recom=length(row_to_com)
    print(row_to_com)
    print(number_recom)
    tracks_to_show %>% dplyr::filter(num %in% c(row_to_com)) %>% dplyr::select(-num)})
    showModal(plot_compare_modal)
    
  })
  
  
  plot_compare_modal=modalDialog(
    fluidPage(
      h3(strong("How similar are your recommendations?"),align="center"),
      plotOutput('sales_plot')
    ),
    size="l"
  )
  
  
  
  output$sales_plot=renderPlot({
    require(ggplot2)
    require(ggradar)
    require(scales)
    print(ggradar(tracks_to_show_new(), axis.label.size=5, legend.text.size=10)) 
  })
  
  
}
shinyApp(ui, server)

