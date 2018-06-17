library(rvest)
get_href <- function(member){
  overall_url <-  sprintf("http://freemusicarchive.org/member/%s/favorites/?d=1&page=1&per_page=200", member)
  webpage <- read_html(overall_url)
  sections <- html_nodes(webpage, "b > a")
  pages <- suppressWarnings(as.data.frame(table(na.omit(as.numeric(as.character(html_text(sections)))), dnn="section"))[-2])
  pages <- rbind(data.frame(section = 1), pages)
  pages[[1]] <- as.character(pages[[1]])
  pages_titles <- list()
  pages_hrefs <- list()
  i <- 1
  for (pag in pages[[1]]){
    url_each <-  sprintf("http://freemusicarchive.org/member/%s/favorites/?d=&page=%s&per_page=200", member, pag)
    webpage_each <- read_html(url_each)
    sections_each <- html_nodes(webpage_each, "span.ptxt-track > a")
    pages_titles[[i]] <- html_text(sections_each)
    pages_hrefs[[i]] <- html_attr(sections_each, 'href')
    i <- i + 1
  }
  pages_titles_df <- as.data.frame(unlist(pages_titles))
  pages_hrefs_df <- as.data.frame(unlist(pages_hrefs))
  pages_each_df <- cbind(pages_titles_df, pages_hrefs_df)
  pages_each_df[pages_each_df == ""] <- NA
  pages_each_df <- na.omit(pages_each_df)
  pages_hrefs_df <- as.data.frame(pages_each_df[[2]])
  colnames(pages_hrefs_df) <- "track_url"
  return(pages_hrefs_df)
}
