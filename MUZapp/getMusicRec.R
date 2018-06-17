user_csv = "hrefs_meta"
getMusicRec <- function(user_csv){
  library(dplyr)
  library(readr)
  library(Matrix)
  library(dummies)
  library(stringr)
  hrefs_meta =  read.csv(sprintf("/students/oyasilyutina/offline_music_recommender/%s.csv", user_csv)) # person to recommed to
  tracks_upd = read.csv("/students/agbataeva/tracks_upd_match.csv")
  
  # creating ids for parsed mus
  idGenerator <- function(n, lengthId) { 
    idList <- stringi::stri_rand_strings(n, lengthId, pattern = "[A-Za-z0-9]") 
    while(any(duplicated(idList))) { 
      idList[which(duplicated(idList))] <- stringi::stri_rand_strings(sum(duplicated(idList), na.rm = TRUE), 
                                                                      lengthId, pattern = "[A-Za-z0-9]") 
    } 
    return(idList) 
  }
  
  
  num = sum(is.na(hrefs_meta$track_id))
  len = 12
  ids = idGenerator(num, len)
  
  hrefs_meta = within(hrefs_meta, track_id[is.na(track_id) == TRUE] <- ids)
  
  
  # dealing with appending genre id
  genres = read.csv("/students/agbataeva/genres.csv")
  genres_m = genres %>% 
    dplyr::select(title, genre_id)
  hrefs_meta$genres = genres_m[match(hrefs_meta$genres, genres_m$title),2]
  
  #hrefs_meta<-rename(hrefs_meta, c("genres"="track_genres"))
  colnames(hrefs_meta)[19] <- "track_genres"
  
  # leaving only new songs
  hrefs_meta_new = hrefs_meta[nchar(hrefs_meta$track_id) == len,]
  
  # adding them to df
  hrefs_meta_new$track_id = as.character(hrefs_meta_new$track_id)
  tracks_upd$track_id = as.character(tracks_upd$track_id)
  #tracks = full_join(hrefs_meta_new, tracks_upd, by=c("track_id", "track_url"))
  
  
  # make all songs genres dummy 
  
  raw_tracks = read.csv("/students/agbataeva/raw_tracks.csv")
  
  raw_tracks$track_id = as.character(raw_tracks$track_id)
  tracks_upd$track_id = as.character(tracks_upd$track_id)
  #tracks$track_id = as.character(tracks$track_id)
  tracks_all <- inner_join(tracks_upd, raw_tracks, by = "track_id")
  tracks_all <-tracks_all[rowSums(is.na(tracks_all)) != ncol(tracks_all), ]
  tracks_all <- cbind(tracks_all, dummy(tracks_all$track_genres, sep = "_"))
  # genres<-dplyr::select(genres, top_level, track_genres)
  # genres$genre_id<-as.numeric(genres$track_genres)
  # tracks_all$track_genres<-as.numeric(tracks_all$track_genres)
  # library(plyr)
  # tracks_all <- inner_join(tracks_all,genres , by = "track_genres")
  
  # filtering df
  tracks_all$X = NULL
  tracks_all = tracks_all %>% 
    dplyr::select(-track_listens.y, -track_lyricist,-track_number,-track_publisher,-track_title,-track_image_file,-track_information,-track_instrumental,-license_title,-license_url,-tags,-track_composer,-track_copyright_c,-track_copyright_p,-track_date_created,-track_date_recorded,-track_disc_number,-track_duration,-track_explicit,-track_explicit_notes,-track_favorites.y,-track_file,-album_id,-album_title,-album_url,-artist_id,-artist_name,-artist_url,-artist_website, -license_image_file,    -license_image_file_large,-license_parent_id, -track_language_code)
  
  # pca
  
  tracks_upd = tracks_all[,colSums(is.na(tracks_all))<nrow(tracks_all)]
  tracks_upd = tracks_upd[,sapply(tracks_upd, function(v) var(v, na.rm=TRUE)!=0)]
  
  tracks_upd[is.na(tracks_upd)] <- 0
  
  rownames(tracks_upd) = tracks_upd$track_id
  tracks_upd[1] <- NULL
  
  library(caret)
  preprocessParams = preProcess(tracks_upd, method=c("center", "scale", "pca"))
  # summarize transform parameters
  
  tracks_mod = predict(preprocessParams, tracks_upd)
  tracks_mod$track_url.x = NULL
  tracks_mod$track_url.y = NULL
  
  # converting to matrix for sim calc
  
  tracks = as.data.frame(tracks_mod)
  rownames(tracks) = rownames(tracks_upd)
  is.na(tracks) <- sapply(tracks, is.infinite)
  tracks[is.na(tracks)] = 0
  
  tracks_matrix = as.matrix(tracks)
  m <- Matrix(tracks_matrix, sparse = TRUE)
  
  fast_row_normalize <- function(m){
    d <- Diagonal(x=1/sqrt(rowSums(m^2)))
    return(t(crossprod(m, d)))
  }
  
  mod_m = fast_row_normalize(m)
  sim <- tcrossprod(mod_m)
  sim_df = as.data.frame(as.matrix(sim))
  
  rownames(sim_df) = rownames(tracks)
  colnames(sim_df) = rownames(sim_df) 
  
  # recommending to the user
  
  # selecting only relevant columns
  rec_hrefs = c()
  for (href in hrefs_meta$track_id){
    href = as.character(href)
    rec_hrefs = c(rec_hrefs, href)
  }
  
  # selects only those column which names are present in df
  names.use <- names(sim_df)[(names(sim_df) %in% rec_hrefs)]
  rec_df <- as.data.frame(sim_df[, names.use], row.names = rownames(tracks))
  rec_df = add_rownames(rec_df, "track_id")
  
  # sorting the cols
  rec_df = rec_df %>% 
    filter(rec_df[,2] > 0.4 & rec_df[,3] > 0.5)
  rec_df = as.data.frame(rec_df)
  rec_for_user = rec_df[order(-rec_df[,2:ncol(rec_df)]),]
  
  # output 
  
  tracks = read.csv("/students/agbataeva/tracks.csv")
  genres = read.csv("/students/agbataeva/genres.csv")
  
  tracks_end = tracks %>% 
    select(track_id,acousticness,danceability,energy,instrumentalness,liveness,speechiness)
  
  raw_tracks_end = raw_tracks %>% 
    select(track_id,album_title, artist_name, track_title, track_image_file, track_genres)
  
  genres_end = genres %>% 
    dplyr::select(genre_id, title)
  
  #genres_end = dplyr::rename(genres_end, c("genre_id" = "track_genres"))
  colnames(genres_end)[1] <- "track_genres"
  
  rec_for_user$track_id = as.character(rec_for_user$track_id)
  tracks_end$track_id = as.character(tracks_end$track_id)
  raw_tracks_end$track_id = as.character(raw_tracks_end$track_id)
  
  rec_for_user = left_join(rec_for_user, tracks_end, by="track_id")
  rec_for_user = left_join(rec_for_user, raw_tracks_end, by="track_id")
  rec_for_user = left_join(rec_for_user, genres_end, by="track_genres")
  return(rec_for_user)
}


