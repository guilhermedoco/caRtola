######################
# INFO ---------------
######################

# This script scrapes team data from the cartola api and writes it down to file tabela-times.csv
# Author: Henrique Gomide

setwd("~/caRtola")

library(jsonlite)
library(lubridate)
library(tidyverse)

fetchRoundData <- function(url) {
  # Returns data frame with dates and rounds for Brasileirao 2019
  
  result <- jsonlite::fromJSON(url)
  result$inicio <- date(ymd_hms(result$inicio))
  result$fim <- date(ymd_hms(result$fim))
  result <- gather(result, `inicio`, `fim`, key = "marco", value = "data")
  result <- arrange(result, data)
  
  temp.df <- data.frame(data = seq(as.Date(min(result$data)), as.Date(max(result$data)), by = "days" ))
  result <- left_join(temp.df, result, by = "data")
  result <- 
    result %>%
    mutate(index = lead(rodada_id) - lag(rodada_id))
  
  result$filter <- ifelse(!is.na(result$rodada_id) | result$index == 0, TRUE, FALSE)
  result <- 
    result %>%
    filter(filter == TRUE) %>%
    select(data, rodada_id) %>%
    fill(data, rodada_id, .direction = "down")
  
  return(result)
  
}

fetchMatchDetail <- function(round) {
  # Returns a data frame with all matches results from the cartola api until a given round.
  # round - Brasileirao round. E.g., If you insert n=3, data will be collected until the round 3.
  
  round_dates <- fetchRoundData("https://api.cartolafc.globo.com/rodadas")
  
  url_vec <- c()
  for (i in 1:round) {
    url_vec[i] <- paste0("https://api.cartolafc.globo.com/partidas/", i)
  }
  
  matches_list <- list()
  
  for (j in 1:length(url_vec)) {
    
    matches <- jsonlite::fromJSON(url_vec[j])
    matches <- matches$partidas
    matches <- dplyr::select(matches, 
                             partida_data, clube_casa_id, clube_visitante_id,
                             placar_oficial_mandante, placar_oficial_visitante)
    matches$partida_data <- date(ymd_hms(matches$partida_data))
    
    matches_list[[j]] <- matches
    
  }
  
  matches <- do.call("rbind", matches_list)
  matches <- left_join(matches, round_dates, by = c("partida_data" = "data"))
  
  # Standardize names to previous years
  names(matches) <- c("date", "home_team", "away_team", 
                      "home_score", "away_score", "round")
  
  return(matches)
  
}

# Write csv
write.csv(fetchMatchDetail(round = 4), "data/2019/2019_partidas.csv", row.names = FALSE)
