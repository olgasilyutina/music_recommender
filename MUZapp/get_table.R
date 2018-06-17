library(dplyr)
library(rvest)
library(readr)
library(utils)
library(shiny)

source("~/offline_music_recommender/get_href.R")
member="eggy"
get_table <- function(member){
  setwd("~/offline_music_recommender")
  overall_url <-  sprintf("http://freemusicarchive.org/member/%s/favorites/?d=1&page=1&per_page=200", member)
  webpage <- read_html(overall_url)
  sections <- html_nodes(webpage, "b > a")
  pages <- suppressWarnings(as.data.frame(table(na.omit(as.numeric(as.character(html_text(sections)))), dnn="section"))[-2])
  pages <- rbind(data.frame(section = 1), pages)
  pages[[1]] <- as.character(pages[[1]])
  pages_tables <- list()
  raw_tracks <- read.csv("/students/agbataeva/tracks_upd_match.csv")
  i <- 1
  for (pag in pages[[1]]){
    url_each <-  sprintf("http://freemusicarchive.org/member/%s/favorites/?d=&page=%s&per_page=200", member, pag)
    webpage_each <- read_html(url_each)
    user_favorite <- html_nodes(webpage_each, xpath = "//div[@class='playlist playlist-lrg']")
    text <- html_text(user_favorite)  # convert to an html table for ease of use
    df <- as.data.frame(strwrap(text))
    df[df==""] <- NA
    df <- na.omit(df)
    tmp <- data.frame(
      X=df$`strwrap(text)`,
      ind=rep(1:4, nrow(df)/4)
    )
    table_favorites <- data.frame(split(tmp$X, tmp$ind,drop=TRUE))
    colnames(table_favorites) <- c("Artist", "Track", "Album", "Genre")
    pages_tables[[i]] <- table_favorites
    i <- i + 1
  }
  pages_table_df <- as.data.frame(pages_tables[[1]])
  #pages_table_df <- as.data.frame(table_favorites)
  hrefs <- get_href(member)
  new_meta <- matrix(ncol=8, nrow=nrow(hrefs))
  colnames(new_meta) = c("bit_rate", "genres", "track_listens", "track_favorites", "track_comments", "artist_url", "artist_comments", "track_url")
  for (track in c(1:length(hrefs$track_url))){ #parse meta data for music out of dataset
    is_in_df = as.character(hrefs$track_url[track]) %in%  raw_tracks$track_url
    if (is_in_df == FALSE){
      new_meta[track, 8] <- as.character(hrefs$track_url[track])
      webpage_track <- read_html(as.character(hrefs$track_url[track])) 
      bit <- html_nodes(webpage_track, xpath = "//div[span/text() = 'Bit Rate']/div[@class='stat-item']/text()")
      new_meta[track, 1] <- html_text(bit)
      genre <- html_nodes(webpage_track, xpath = "//div[@class='stat-item']/a/text()")[1]
      new_meta[track, 2] <- html_text(genre)
      listen <- html_nodes(webpage_track, xpath = "//div[span/text() = 'LISTENS:']/b/text()")
      new_meta[track, 3] <- html_text(listen)
      star <- html_nodes(webpage_track, xpath = "//div[span/text() = 'STARRED:']/b/text()")
      new_meta[track, 4] <- html_text(star)
      com <- html_nodes(webpage_track, xpath = "//div[span/text() = 'COMMENTS:']/b/text()")
      new_meta[track, 5] <- html_text(com)  
      artist <- html_nodes(webpage_track, xpath = "//span[@class='subh1']/a/@href")
      new_meta[track, 6] <- html_text(artist)  
      webpage_artist <- read_html(html_text(artist)) #add num of comment for artist
      art_com <- html_nodes(webpage_artist, xpath = "//div[@class='comment-items']/div[not(contains(.,'There are no comments'))]")
      art_com <- length(art_com)
      new_meta[track, 7] <- art_com
      #times <- html_nodes(webpage_track, xpath = "//div[@class='sbar-stat'][span/text() = 'Lenght:']/b/text()")
      #times <- html_text(times) 
      #new_meta[track, 8] <- as.period(hms(times), unit = "sec")
    }
  }
  
  hrefs_meta <- inner_join(raw_tracks, hrefs, by="track_url")
  new_meta <- as.data.frame(new_meta, stringsAsFactors=FALSE)
  new_meta <- new_meta[rowSums(is.na(new_meta)) != ncol(new_meta),]
  i <- sapply(hrefs_meta, is.numeric)
  hrefs_meta[i] <- lapply(hrefs_meta[i], as.character)
  hrefs_meta <- bind_rows(hrefs_meta, new_meta)
  hrefs_meta$member <- rep(member, nrow(hrefs_meta))
  empty_df = as.data.frame(matrix(ncol=21, nrow=0))
  colnames(empty_df) <- colnames(hrefs_meta)
  write.csv(empty_df, "hrefs_meta.csv", row.names = F)
  write.table(hrefs_meta, "hrefs_meta.csv", sep = ",",row.names=F, col.names = F, append = T)
  
  #hrefs_meta$track_file <- paste0("https://freemusicarchive.org/file/", hrefs_meta$track_file)
  #for (r in c(1:length(pages_table_df))){
  #  try(utils::download.file(hrefs_meta[r, "track_file"], sprintf("~/offline_music_recommender/%s_%s.mp3", member, r)))
  #}
  #pages_table_df[,ncol(pages_table_df)+1] <- NA
  #k=1
  #for (m in list.files(pattern = "\\.mp3$")){
  #  pages_table_df[[5]][k] = as.character(tags$audio(src = sprintf("%s", m), type = "audio/mp3", autoplay = NA, controls = NA))
  #  k=k+1
  #}
  #colnames(pages_table_df)[5] <- "Play"
  return(pages_table_df)
}

